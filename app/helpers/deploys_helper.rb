# frozen_string_literal: true

# Helpers used in deploy page
module DeploysHelper
  def titleize_provisioner(provisioner)
    name = provisioner.match(/(.*)_(\d+)/)
    title_name = name.captures[0].titleize
    "#{name.captures[1].to_i + 1}. #{title_name}"
  end
end
