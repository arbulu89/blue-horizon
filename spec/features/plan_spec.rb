# frozen_string_literal: true

require 'rails_helper'

describe 'planning', type: :feature do
  let(:plan_button) { I18n.t('plan') }

  before do
    populate_sources(include_mocks: false)
  end

  context 'without a current plan' do
    let(:expected_plan_json) { current_plan_fixture_json }

    before do
      visit(plan_path)
    end

    it 'loads without a pre-generated plan' do
      expect(find('#plan')).to have_no_content
    end

    it 'generates a new plan' do
      click_on(id: 'update-plan')

      expect(JSON.parse(find('#plan code.output').text))
        .to eq(JSON.parse(expected_plan_json))
      expect(File.exist?(
               working_path.join('current_plan')
             )
            ).to be true
    end
  end

  context 'with a current plan' do
    let!(:current_plan) { current_plan_fixture }

    it 'displays the current plan' do
      visit(plan_path)
      expect(find('#plan code.output')).to have_content(current_plan)
    end
  end

  context 'with the dynamic plan view' do
    let!(:current_plan) { current_plan_fixture }

    before do
      Rails.configuration.x.terraform_plan_view = 'plans/dynamic'
    end

    it 'displays the current plan' do
      visit(plan_path)
      expect(find('#plan')).to have_selector('table.table')
    end
  end

  context 'with the sap_azure plan view' do
    let!(:current_plan) { sap_azure_plan_fixture }

    before do
      Rails.configuration.x.terraform_plan_view = 'plans/sap_azure'
    end

    it 'displays the current plan' do
      visit(plan_path)
      plan_element = find('#plan')
      expect(plan_element.text).to include 'System settings'
      expect(plan_element.text).to include 'Resource group'
      expect(plan_element.text).to include 'HANA nodes'
      expect(plan_element.text).to include 'Virtual networks'
      expect(plan_element.text).to include 'Security group'
    end
  end
end
