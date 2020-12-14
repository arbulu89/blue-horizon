# frozen_string_literal: true

# Helpers used in cluster sizing
module ClustersHelper
  def instance_types_doc_url_for(framework)
    Rails.configuration.x.external_instance_types_link[framework]
  end

  def card_text(instance_type)
    saps = instance_type.details['SAP application performance standard']
    # Get memory part from details box and remove last word
    memory = instance_type.details['Details'].split(',')[1][/(.*)\s/, 1].strip
    "Up to #{memory} database size and #{saps}"
  end
end
