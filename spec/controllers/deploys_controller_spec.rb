# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeploysController, type: :controller do
  render_views
  let(:example) { described_class.new }

  context 'when deploying terraform plan' do
    let(:ruby_terraform) { RubyTerraform }
    let(:terra_stderr) { ruby_terraform.configuration.stderr }
    let(:variable_instance) { Variable.new('') }

    let(:terraform_tfvars) { 'terraform.tfvars' }
    let(:terra) { Terraform }
    let(:instance_terra) { instance_double(Terraform) }

    before do
      allow(terra).to receive(:new).and_return(instance_terra)
    end

    it 'deploys a plan successfully' do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read)
      allow(JSON).to receive(:parse).and_return(foo: 'bar')
      allow(instance_terra).to receive(:apply)
      allow(instance_terra).to(
        receive(:get_planned_resources)
          .and_return(['1', '2', '3'])
      )

      get :update, format: :json

      expect(KeyValue.get(:planned_resources_count)).to eq(3)
      expect(instance_terra).to(
        have_received(:apply)
          .with(
            directory:    working_path,
            auto_approve: true,
            no_color:     true
          )
      )
    end

    it 'raise exception' do
      allow(instance_terra).to(
        receive(:get_planned_resources)
          .and_return(['1', '2', '3'])
      )
      allow(instance_terra).to(
        receive(:apply)
          .and_raise(RubyTerraform::Errors::ExecutionError)
      )
      expect do
        get :update, format: :json
      end.to raise_exception(RubyTerraform::Errors::ExecutionError)
    end

    it 'writes error in the log' do
      allow(ruby_terraform.configuration).to(
        receive(:stderr)
          .and_return(StringIO.new('Something went wrong'))
      )
      allow(controller).to(
        receive(:update_progress)
          .and_return('progress')
      )

      get :send_current_status, format: :json

      filename = Rails.configuration.x.terraform_log_filename
      expect(File).to exist(filename)
      file_content = File.read(filename)
      expect(
        file_content.include?('Something went wrong')
      ).to be true
    end

    it 'can show deploy output' do
      allow(Terraform).to(
        receive(:stdout)
          .and_return(
            StringIO.new('hello world! Apply complete!')
          )
      )

      allow(controller).to(
        receive(:update_progress)
          .and_return('progress')
      )

      allow(ruby_terraform).to receive(:apply)

      get :send_current_status, format: :json

      expect(controller).to(
        have_received(:update_progress)
          .with('hello world! Apply complete!', nil)
            .at_least(:once)
      )

      expect(response).to be_success
    end

    it 'can show error output when deploy fails' do
      allow(JSON).to receive(:parse).and_return(foo: 'bar')

      allow(Terraform).to receive(:stderr).and_return(StringIO.new('Error'))
      allow(Terraform).to receive(:stdout).and_return(StringIO.new('Creating'))

      allow(controller).to(
        receive(:update_progress)
          .and_return('progress')
      )

      get :send_current_status, format: :json

      expect(controller).to(
        have_received(:update_progress)
          .with('Creating', 'Error')
            .at_least(:once)
      )

      expect(response).to be_success
    end
  end

  context 'when destroying terraform resources' do
    let(:ruby_terraform) { RubyTerraform }

    it 'destroys the resources deployed' do
      allow(ruby_terraform).to receive(:destroy)
      allow(File).to receive(:exist?).and_return(true)
      allow(controller).to receive(:redirect_to).with(action: 'show')

      delete :destroy

      expect(response).to be_success
      expect(flash[:notice]).to(
        include('Terraform resources have been destroyed.')
      )
    end

    it 'shows error when destroying resources' do
      allow(ruby_terraform).to(
        receive(:destroy)
          .and_raise(RubyTerraform::Errors::ExecutionError)
      )
      allow(File).to receive(:exist?).and_return(true)
      allow(controller).to receive(:redirect_to).with(action: 'show')

      delete :destroy

      expect(response).to be_success
      expect(flash[:error]).to(
        include('Error: Terraform destroy has failed.')
      )
    end
  end

  context 'when updating the terraform progress' do
    let(:ruby_terraform) { RubyTerraform }

    it 'updates the terraform progress' do
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(:update_terraform_progress, deploy_output, nil)

      expect(progress).to eq(
        'infra-bar' => {
          progress: 50,
          text:     'Creating resources...',
          success:  true
        }
      )
    end

    it 'updates the terraform progress blank content' do
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(:update_terraform_progress, '', nil)
      expect(progress).to eq({})

      progress = example.send(:update_terraform_progress, nil, nil)
      expect(progress).to eq({})
    end

    it 'updates the terraform progress with failed' do
      KeyValue.set(:planned_resources_count, 5)
      progress = example.send(:update_terraform_progress, deploy_output, 'error')

      expect(progress).to eq(
        'infra-bar' => {
          progress: 100,
          text:     'Failed',
          success:  false
        }
      )
    end

    it 'updates the terraform progress with finished' do
      KeyValue.set(:planned_resources_count, 5)
      progress = example.send(:update_terraform_progress, deploy_output, nil)

      expect(progress).to eq(
        'infra-bar' => {
          progress: 100,
          text:     'Finished',
          success:  true
        }
      )
    end

    it 'updates the terraform progress with finished even with more resources' do
      KeyValue.set(:planned_resources_count, 4)
      progress = example.send(:update_terraform_progress, deploy_output, nil)

      expect(progress).to eq(
        'infra-bar' => {
          progress: 100,
          text:     'Finished',
          success:  true
        }
      )
    end
  end

  context 'when the provisioners are found' do
    let(:terra) { Terraform }
    let(:instance_terra) { instance_double(Terraform) }

    before do
      allow(terra).to receive(:new).and_return(instance_terra)
    end

    it 'the provisioners are found' do
      data = [
        {
          'address' => 'data'
        },
        {
          'address' => '.hana_provision.data.provision[0]'
        },
        {
          'address' => '.hana_provision.data.provision[1]'
        },
        {
          'address' => 'data 2'
        }
      ]
      allow(instance_terra).to(
        receive(:get_planned_resources)
          .and_return(data)
      )
      provisioners = example.send(:find_provisioners)
      expect(provisioners).to eq(['hana_provision_0', 'hana_provision_1'])
    end

    it 'the provisioners are initialized' do
      example.send(
        :init_provisioners, ['hana_provision_0', 'hana_provision_1']
      )

      expect(KeyValue.get('hana_provision_0')).to eq(:not_started)
      expect(KeyValue.get('hana_provision_1')).to eq(:not_started)
    end
  end

  context 'when updating the provisioners progress' do
    it 'updates the provisioner progress - not started' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :not_started)
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(
        :update_progress, 'data', nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 0,
        text:     'Not started',
        success:  true
      )
    end

    it 'updates the provisioner progress - initializing' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :not_started)
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(
        :update_progress, provisioning_deploy_output, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 0,
        text:     'Initializing machine...',
        success:  true
      )
    end

    it 'updates the provisioner progress - still initializing' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :initializing)
      KeyValue.set(:planned_resources_count, 10)
      data = provisioning_deploy_output.gsub('Configuring operative', '')
      progress = example.send(
        :update_progress, data, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 0,
        text:     'Initializing machine...',
        success:  true
      )
    end

    it 'updates the provisioner progress - start configuring os' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :initializing)
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(
        :update_progress, provisioning_deploy_output, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 0,
        text:     'Configuring operative system...',
        success:  true
      )
    end

    it 'updates the provisioner progress - finished configuring os' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :configuring_os)
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(
        :update_progress, provisioning_deploy_output, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 60,
        text:     'Provisioning machine...',
        success:  true
      )
    end

    it 'updates the provisioner progress - start provisioning' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :configuring_os)
      KeyValue.set(:planned_resources_count, 10)
      data = provisioning_deploy_output.gsub('Provisioning system', '')
      progress = example.send(
        :update_progress, data, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 5,
        text:     'Configuring operative system...',
        success:  true
      )
    end

    it 'updates the provisioner progress - provisioning' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :provisioning)
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(
        :update_progress, provisioning_deploy_output, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 60,
        text:     'Provisioning machine...',
        success:  true
      )
    end

    it 'updates the provisioner progress - failed' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :provisioning)
      KeyValue.set(:planned_resources_count, 10)
      data = "#{provisioning_deploy_output}.hana_provision.provision[0] (remote-exec): Error::Deployment failed"
      progress = example.send(
        :update_progress, data, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 60,
        text:     'Failed',
        success:  false
      )
    end

    it 'updates the provisioner progress - completed' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :not_started)
      KeyValue.set(:planned_resources_count, 10)
      data = "#{provisioning_deploy_output}.hana_provision.provision[0] (remote-exec): Creation complete after"
      progress = example.send(
        :update_progress, data, nil
      )

      expect(progress['hana_provision_0']).to eq(
        progress: 100,
        text:     'Finished',
        success:  true
      )
    end

    it 'updates the provisioner progress - already done' do
      KeyValue.set(:provisioners, ['hana_provision_0'])
      KeyValue.set(:hana_provision_0, :finished)
      KeyValue.set(:planned_resources_count, 10)
      progress = example.send(
        :update_progress, provisioning_deploy_output, nil
      )

      expect(progress['hana_provision_0']).to eq(nil)
    end
  end
end
