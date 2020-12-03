# frozen_string_literal: true

# helper for rendering `terraform show` output as a plan
module CustomHelpers
  def plan_resources(plan)
    return {} if plan.blank?

    find_resources_recursively(plan.dig('planned_values', 'root_module'))
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
