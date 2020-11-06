# frozen_string_literal: true

require 'rails_helper'

describe 'sap azure plan', type: :feature do
  before do
    copy_plan_fixture
    copy_sources
    Rails.configuration.x.terraform_plan_view = 'plans/sap_azure'
  end

  it 'displays various sections of the plan' do
    visit(plan_path)

    expect(page).to have_selector('#plan')

    plan_block = find('#plan')
    expect(plan_block).to have_text 'System settings'
    expect(plan_block).to have_text 'Resource group'
    expect(plan_block).to have_text 'HANA nodes'
    expect(plan_block).to have_text 'Virtual networks'
    expect(plan_block).to have_text 'Security group'
  end
end
