# frozen_string_literal: true

# Helpers used in deploy page
module DeploysHelper
  def titleize_provisioner(provisioner)
    t("provisioning_bars.#{provisioner}")
  end
end
