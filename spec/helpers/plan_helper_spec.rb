require 'rails_helper'

describe PlanHelper do
    context 'with empty terraform show output' do
    it 'renders nothing' do
      expect(helper.terraform_plan(nil)).to be == ""
    end
  end
end
