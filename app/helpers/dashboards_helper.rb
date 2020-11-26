# frozen_string_literal: true

# Helpers used in dashboard vies
module DashboardsHelper
  def using_console?
    controller_name == 'dashboards'
  end

  def first_item
    Rails.configuration.x.top_menu_items[0][:sidebar].to_h.keys[0]
  end

  def console_sidebar_menu_items(request_id)
    Rails.configuration.x.top_menu_items.collect do |menu_item|
      next if menu_item['sidebar'].blank?

      sidebar = menu_item['sidebar']
      return sidebar if get_dashboard_url(request_id, menu_item).present?
    end
    return OpenStruct.new
  end

  def dashboard(request_id, format_values)
    Rails.configuration.x.top_menu_items.collect do |menu_item|
      next if menu_item['sidebar'].blank?

      url = get_dashboard_url(request_id, menu_item)
      next if url.nil?

      return url % format_values
    end
    return
  end

  def get_dashboard_url(request_id, menu_item)
    return if menu_item['sidebar'].blank?

    menu_item['sidebar'].each_pair do |key, value|
      return value if request_id == key

      next unless value.is_a?(OpenStruct)

      value.each_pair do |child_key, child_value|
        return child_value if request_id == child_key
      end
    end
    return
  end
end
