# frozen_string_literal: true

require 'rails_helper'

describe SapAzurePlanHelper do
  context 'with empty input' do
    let!(:input) { [nil, '', {}, []] }

    it 'returns an empty hash' do
      input.each do |i|
        expect(helper.sap_azure_resources(i)).to eq({})
      end
    end
  end
end
