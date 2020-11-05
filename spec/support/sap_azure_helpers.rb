# frozen_string_literal: true

module SapAzureHelpers
  def sap_azure_plan_fixture
    source_path = Rails.root.join('spec', 'fixtures', 'sap_azure')
    dest_path = Rails.configuration.x.source_export_dir

    FileUtils.cp_r Dir.glob(source_path.join('*')) << source_path.join('.terraform'), dest_path

    sap_azure_plan_fixture_json
  end

  def sap_azure_plan_fixture_json
    File.read(Rails.root.join('spec', 'fixtures', 'sap_azure', 'current_plan.json'))
  end
end

RSpec.configure do |config|
  config.include SapAzureHelpers
end
