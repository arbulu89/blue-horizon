# frozen_string_literal: true

require 'ruby_terraform'
require 'storage_account'
require 'fileutils'

class PlansController < ApplicationController
  include FileUtils
  include I18n
  before_action :variables

  def show
    return unless helpers.can(plan_path)

    terra = Terraform.new
    @trigger_update = (@variables.updated_at > Terraform.last_action_at) ||
                      !File.file?(terra.saved_plan_path)
    @plan = ''

    unless @trigger_update
      terra.show
      plan_raw_json = Terraform.stdout.string
      @plan = JSON.parse(plan_raw_json, object_class: OpenStruct)
      @plan.raw_json = plan_raw_json
      @trigger_update = @plan.blank?
    end

    respond_to do |format|
      format.html
      format.json do
        send_data(
          plan_raw_json,
          disposition: 'attachment',
          filename:    'terraform_plan.json'
        )
      end
    end
  end

  def update
    prep
    return unless @exported_vars

    result = sanity_check
    if result.is_a?(Hash)
      @trigger_update = false
      @error = result[:error]
      respond_to do |format|
        format.html do
          flash[:error] = result[:error][:message]
          render 'show'
        end
      end
    else
      redirect_to(action: 'show')
    end
  end

  private

  def variables
    @variables ||= Variable.load
  end

  def export_path
    exported_dir_path = Rails.configuration.x.source_export_dir
    exported_vars_file_path = Variable::DEFAULT_EXPORT_FILENAME
    return File.join(exported_dir_path, exported_vars_file_path)
  end

  def read_exported_vars
    @variables.export
    export_var_path = export_path
    @exported_vars = nil
    if File.exist?(export_var_path)
      vars = File.read(export_var_path)
      @exported_vars = JSON.parse(vars)
    else
      logger.error t('flash.export_failure')
      flash.now[:error] = t('flash.export_failure')
      return render json: flash.to_hash
    end
  end

  def read_exported_sources
    sources = Source.all
    sources.each(&:export)
  end

  def cleanup
    log_file = File.basename(Rails.configuration.x.terraform_log_filename, '.*')
    log_file_abs = Rails.configuration.x.source_export_dir.join(log_file)
    exports = Rails.configuration.x.source_export_dir.join('*')
    filtered_exports = Dir.glob(exports).reject do |item|
      item.match(/#{log_file_abs}.*/)
    end
    Rails.logger.debug("cleaning up #{filtered_exports}")
    FileUtils.rm_r(filtered_exports, secure: true)
  end

  def prep
    cleanup
    read_exported_vars
    read_exported_sources
  end

  def sanity_check
    # Check ssh key sanity
    ssh_result = check_ssh_pub_key
    return ssh_result if ssh_result.is_a?(Hash)

    # Check storage account values sanity
    storage_result = check_storage_account
    return storage_result if storage_result.is_a?(Hash)

    # Check terraform plan sanity
    plan_result = check_terraform_plan
    return plan_result if plan_result.is_a?(Hash)
  end

  def check_ssh_pub_key
    ssh_pattern = Regexp.new(
      '^(ssh-rsa AAAAB3NzaC1yc2|ecdsa-sha2-nistp256 '\
      'AAAAE2VjZHNhLXNoYTItbmlzdHAyNT|ecdsa-sha2-nistp384 '\
      'AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzOD|ecdsa-sha2-nistp521 '\
      'AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1Mj|ssh-ed25519 AAAAC3NzaC1lZDI1NTE5|ssh-dss '\
      'AAAAB3NzaC1kc3)[0-9A-Za-z+/]+[=]{0,3}( .*)?$'
    )
    attributes = @variables.attributes
    ssh_file = Rails.configuration.x.source_export_dir.join(
      attributes['ssh_authorized_key_file']
    )
    return true if ssh_pattern.match(File.read(ssh_file))

    return {
      error: {
        message: 'Error checking the authorized ssh public key',
        output:  I18n.t('ssh_key_error')
      }
    }
  end

  def check_storage_account
    attributes = @variables.attributes
    StorageAccount.new.check_resource(
      attributes['storage_account_name'],
      attributes['storage_account_key'],
      attributes['hana_installation_software_path']
    )
  end

  def check_terraform_plan
    terra = Terraform.new
    args = {
      directory: Rails.configuration.x.source_export_dir,
      plan:      terra.saved_plan_path,
      no_color:  true,
      var_file:  Variable.load.export_path
    }
    terra.plan(args)
  end
end
