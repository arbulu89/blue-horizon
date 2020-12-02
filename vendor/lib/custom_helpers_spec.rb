# frozen_string_literal: true

require 'rails_helper'

describe CustomHelpers do
  subject(:helper) { Class.new.include(described_class).new }

  describe 'plan_resources' do
    context 'with empty input' do
      let!(:input) { [nil, '', {}, []] }

      it 'returns an empty hash' do
        input.each do |i|
          expect(helper.plan_resources(i)).to eq({})
        end
      end
    end
  end
end
