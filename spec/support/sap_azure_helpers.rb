# frozen_string_literal: true

module SapAzureHelpers
  def sap_azure_plan_fixture
    source_path = Rails.root.join('spec', 'fixtures', 'sap_azure')
    dest_path = Rails.configuration.x.source_export_dir

    FileUtils.cp_r Dir.glob(source_path.join('**/*')), dest_path
  end

  def sap_azure_populate_sources
    source_path ||= Rails.root.join('vendor', 'sources')
    dest_path = Rails.configuration.x.source_export_dir

    Source.import_dir(source_path)

    FileUtils.cp_r Dir.glob(source_path.join('**/*')), dest_path
  end
end

RSpec.configure do |config|
  config.include SapAzureHelpers
end
