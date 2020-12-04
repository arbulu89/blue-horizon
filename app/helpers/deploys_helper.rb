# frozen_string_literal: true

# Helpers used in deploy page
module DeploysHelper
  def titleize_provisioner(provisioner)
    title = t("provisioning_bars.#{provisioner}")
    "#{title}..."
  end

  def task_loading_icon(id)
    tag.img(
      src:   asset_path('bubble_loading.svg'),
      alt:   t('tooltips.loading'),
      title: t('tooltips.loading'),
      class: 'eos-icons eos-18',
      style: 'display: none;',
      id:    id
    )
  end
end
