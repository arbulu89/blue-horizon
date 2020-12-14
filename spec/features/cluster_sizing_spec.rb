# frozen_string_literal: true

require 'rails_helper'

describe 'cluster sizing', type: :feature do
  let(:terra) { Terraform }
  let(:instance_terra) { instance_double(Terraform) }
  let(:mock_location) { Faker::Internet.slug }

  before do
    allow(terra).to receive(:new).and_return(instance_terra)
    allow(instance_terra).to receive(:validate)
    populate_sources
  end

  describe 'in Azure' do
    let(:cloud_framework) { 'azure' }
    let(:instance_types) do
      Cloud::InstanceType.load(
        Rails.root.join('vendor', 'data', "#{cloud_framework}-types.json")
      )
    end
    let(:random_instance_type_key) { instance_types.sample.key }

    before do
      Rails.configuration.x.cloud_framework = cloud_framework
      Rails.configuration.x.allow_custom_instance_type = true
      Rails.configuration.x.show_instance_type_tip = true
      allow(Cloud::InstanceType)
        .to receive(:for)
        .with(cloud_framework)
        .and_return(instance_types)
      visit '/cluster'
    end

    it 'lists the instance types' do
      instance_types.each do |instance_type|
        expect(page).to have_content(instance_type.name)
      end
    end

    it 'HA toggle is present' do
      expect(page).to have_selector('input#cluster_hana_ha_enabled')
    end
  end
end
