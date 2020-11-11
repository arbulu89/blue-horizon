# frozen_string_literal: true

# helper for rendering `terraform show` output as a plan
module SapAzurePlanHelper
  def sap_azure_resources(plan)
    return {} if plan.blank?

    find_resources_recursively(plan.dig('planned_values', 'root_module'))
  end

  def plan_section_header(title, icon='abstract')
    icon_tag = tag.i icon, class: 'eos-icons'
    tag.h4 icon_tag + title
  end

  # i don't care about your cyclomatic complexity, rubocop, I want a big dumb switch.
  def resource_icon(resource) # rubocop:disable Metrics/CyclomaticComplexity
    case resource['type']
    when /security_group/
      'security'
    when /security_rule/
      'network_policy'
    when /subnet$|virtual_network$/
      'network'
    when /public_ip$|network_interface$/
      'ip'
    when /virtual_machine/
      'node'
    when /key/
      'vpn_key'
    when /storage/
      'storage'
    when /resource_group/
      'namespace'
    else
      'abstract'
    end
  end

  private

  def find_resources_recursively(tf_module)
    # ignore data and null resources and convert the resources array to a hash, allowing lookup by address
    resources = (tf_module['resources'] || [])
                .select { |tf_resource| tf_resource['type'] != 'null_resource' && tf_resource['mode'] == 'managed' }
                .index_by { |tf_resource| tf_resource['address'] }

    (tf_module['child_modules'] || [])
      .each { |tf_child_module| resources = resources.merge(find_resources_recursively(tf_child_module)) }

    resources
  end
end
