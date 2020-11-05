# frozen_string_literal: true

require 'rails_helper'

describe 'sap azure planning', type: :feature do
  before do
    sap_azure_populate_sources
    sap_azure_plan_fixture
    Rails.configuration.x.terraform_plan_view = 'plans/sap_azure'
  end

  it 'displays the current plan' do
    visit(plan_path)

    expect(page).to have_selector('#update-plan')

    click_on(id: 'update-plan')

    expect(page).to have_selector('#plan')

    plan_element = find('#plan')
    expect(plan_element).to have_text 'System settings'
    expect(plan_element).to have_text 'Resource group'
    expect(plan_element).to have_text 'HANA nodes'
    expect(plan_element).to have_text 'Virtual networks'
    expect(plan_element).to have_text 'Security group'
  end
end
