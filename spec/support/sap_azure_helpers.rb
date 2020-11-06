# frozen_string_literal: true

module SapAzureHelpers
  def copy_plan_fixture
    source_path = Rails.root.join('spec', 'fixtures', 'sap_azure')
    dest_path = Rails.configuration.x.source_export_dir

    FileUtils.cp_r Dir.glob(source_path.join('**/*')), dest_path
  end

  def plan_fixture_json
    plan_json_path = Rails.configuration.x.source_export_dir.join('current_plan.json')
    copy_plan_fixture unless File.exist?(plan_json_path)
    File.read(plan_json_path)
  end

  def copy_sources
    source_path = Rails.root.join('vendor', 'sources')
    dest_path = Rails.configuration.x.source_export_dir

    FileUtils.cp_r Dir.glob(source_path.join('**/*')), dest_path
  end
end

RSpec.configure do |config|
  config.include SapAzureHelpers
end
