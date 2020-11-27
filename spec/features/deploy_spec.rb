# frozen_string_literal: true

require 'rails_helper'

describe 'deploy', type: :feature do
  before do
    populate_sources(include_mocks: false)
  end

  context 'when deploying terraform plan' do
    let!(:current_plan) { current_plan_fixture }
    let(:terra) { Terraform }
    let(:instance_terra) { instance_double(Terraform) }

    before do
      allow(terra).to receive(:new).and_return(instance_terra)
    end

    it 'shows the progress bars' do
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
      allow(instance_terra).to(
        receive(:validate)
      )

      visit(deploy_path)

      expect(page).to have_selector('div.progress-bar#infra-bar')
      expect(page).to have_selector('div.progress-bar#hana_provision_0')
      expect(page).to have_selector('div.progress-bar#hana_provision_1')
    end
  end
end
