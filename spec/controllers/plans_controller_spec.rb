# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlansController, type: :controller do
  let(:json_instance) { JSON }
  let(:ruby_terraform) { RubyTerraform }
  let(:terra) { Terraform }
  let(:storage) { StorageAccount }
  let(:instance_terra) { instance_double(Terraform) }
  let(:instance_storage) { instance_double(StorageAccount) }
  let(:ssh_file_name) { 'ssh_file' }
  let(:ssh_content) { 'ssh-rsa AAAAB3NzaC1yc2xxxxxx=== blue-horizon@test' }
  let(:ssh_file) { Rails.configuration.x.source_export_dir.join(ssh_file_name) }
  let(:attributes_hash) do
    {
      ssh_authorized_key_file:         ssh_file_name,
      storage_account_name:            'name',
      storage_account_key:             'key',
      hana_installation_software_path: 'hana_path'
    }
  end
  let(:variables) { Variable.load }

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(ssh_file).and_return(ssh_content)
    populate_sources(use_sap_azure: true, include_mocks: false)
    variables.attributes = attributes_hash
    variables.are_you_sure = false
    variables.save
  end

  context 'when preparing terraform' do
    let(:variable_instance) { Variable.new('{}') }
    let(:log_file) do
      Logger::LogDevice.new(Rails.configuration.x.terraform_log_filename)
    end

    before do
      allow(terra).to receive(:new).and_return(instance_terra)
      allow(storage).to receive(:new).and_return(instance_storage)
      allow(instance_terra).to receive(:saved_plan_path)
      allow(instance_terra).to receive(:plan).and_return(true)
      allow(instance_storage).to receive(:check_resource).and_return(true)
      allow(controller).to receive(:check_ssh_pub_key).and_return(true)
      allow(File).to receive(:exist?).and_return(true)
    end

    it 'sets the configuration' do
      allow(controller.instance_variable_set(:@exported_vars, 'foo'))

      put :update

      ruby_terraform.configure do |config|
        config.logger do |log_device|
          expect(log_device.targets).to eq([$stdout, log_file])
        end
      end
      expect(File).to exist(Rails.configuration.x.terraform_log_filename)
    end

    it 'exports variables' do
      allow(variable_instance).to receive(:load)
      allow(File).to receive(:exist?).and_return(true)
      allow(controller).to receive(:read_exported_sources)
      allow(json_instance).to receive(:parse).and_return('foo')

      put :update

      expect(json_instance).to have_received(:parse).at_least(:once)
    end
  end

  context 'when not exporting' do
    before do
      allow(File).to receive(:exist?).and_return(false)
      allow(terra).to receive(:new).and_return(instance_terra)
      allow(instance_terra).to receive(:validate).with(true, file: true)
    end

    it 'no exported variables' do
      put :update

      expect(flash[:error]).to match(I18n.t('flash.export_failure'))
    end
  end

  context 'when generating the plan' do
    let(:plan_file) { Rails.root.join(random_path, 'current_plan') }

    before do
      allow(terra).to receive(:new).and_return(instance_terra)
      allow(storage).to receive(:new).and_return(instance_storage)
      allow(instance_terra).to receive(:validate)
      allow(instance_terra).to receive(:saved_plan_path).and_return('plan')
    end

    it 'redirects to showing the plan' do
      allow(instance_terra).to receive(:plan).and_return('')
      allow(instance_storage).to receive(:check_resource).and_return(true)

      put :update

      expect(controller).to redirect_to action: :show
      expect(instance_storage).to(
        have_received(:check_resource)
          .with(
            'name',
            'key',
            'hana_path'
          )
      )
    end

    it 'raises a flash error on ssh file check' do
      ssh_content = 'ssh-rs AAAAB3NzaC1yc2xxxxxx=== blue-horizon@test'
      allow(File).to receive(:read).with(ssh_file).and_return(ssh_content)

      put :update

      expect(flash[:error]).to match('Error checking the authorized ssh public key')
    end

    it 'raises a flash error on storage account check' do
      allow(instance_storage).to receive(:check_resource).and_return(
        error: { message: 'error checking storage', output: 'storage error' }
      )

      put :update

      expect(flash[:error]).to match('error checking storage')
    end

    it 'raises a terraform plan error' do
      allow(instance_storage).to receive(:check_resource).and_return(true)
      allow(instance_terra).to receive(:plan).and_return(
        error: { message: 'error terraform plan', output: 'terraform error' }
      )
      allow(instance_terra).to receive(:saved_plan_path).and_return('plan')

      put :update

      expect(flash[:error]).to match('error terraform plan')
    end
  end

  context 'when showing the plan' do
    let(:file) { File }
    let(:file_write) { File }
    let(:plan_file) { Rails.root.join(random_path, 'current_plan') }
    let(:tfvars_file) { Variable.load.export_path }

    before do
      allow(storage).to receive(:new).and_return(instance_storage)
      allow(Logger::LogDevice).to receive(:new)
      allow(controller).to receive(:cleanup)
      allow(controller).to receive(:check_ssh_pub_key).and_return(true)
      allow(instance_storage).to receive(:check_resource).and_return(true)
      allow(JSON).to receive(:parse).and_return(OpenStruct.new(blue: 'horizon'))
    end

    it 'allows to download the plan' do
      allow(controller.helpers).to receive(:can).and_return(true)
      allow(terra).to receive(:new).and_return(instance_terra)
      allow(instance_terra).to receive(:show)
      allow(ruby_terraform).to receive(:show)
      expected_content = 'attachment; filename="terraform_plan.json"'

      get :show, format: :json

      expect(response.header['Content-Disposition']).to eq(expected_content)
    end

    it 'handles rubyterraform exception' do
      allow(instance_terra).to receive(:saved_plan_path)
      allow(ruby_terraform).to(
        receive(:plan)
          .and_raise(
            RubyTerraform::Errors::ExecutionError,
            'Failed while running \'plan\'.'
          )
      )
      allow(ruby_terraform.configuration).to(
        receive(:stderr)
          .and_return(
            StringIO.new('foo')
          )
      )

      put :update, format: :html

      expect(flash[:error]).to(
        match('Failed while running \'plan\'')
      )

      expect(response.body).to have_content('foo')
    end
  end
end
