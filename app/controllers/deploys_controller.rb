# frozen_string_literal: true

require 'ruby_terraform'

class DeploysController < ApplicationController
  def update
    logger.info('Calling run_deploy')
    RubyTerraform.configuration.stdout = StringIO.new
    RubyTerraform.configuration.stderr = StringIO.new
    @apply_args = {
      directory:    Rails.configuration.x.source_export_dir,
      auto_approve: true,
      no_color:     true
    }
    run_deploy
    logger.info('Deploy finished.')
  end

  def send_current_status
    success = false
    terra_stderr = RubyTerraform.configuration.stderr

    if terra_stderr.is_a?(StringIO) && !terra_stderr.string.empty?
      error = terra_stderr.string
      success = false
      close_log_info
    elsif RubyTerraform.configuration.stdout.is_a?(StringIO)
      @apply_output = RubyTerraform.configuration.stdout.string
      success = true
      if RubyTerraform.configuration.stdout.string.include? 'Apply complete!'
        close_log_info
      end
    end

    html = (render_to_string partial: 'output.html.haml')
    respond_to do |format|
      format.json do
        render json: { new_html: html, success: success,
                       error: error }
      end
    end
    return
  end

  private

  def close_log_info
    set_default_logger_config
    log_path = Rails.configuration.x.source_export_dir.join('tf-apply.log')
    write_output(log_path)
  end

  def set_default_logger_config
    RubyTerraform.configuration.stdout = RubyTerraform.configuration.logger
    RubyTerraform.configuration.stderr = RubyTerraform.configuration.logger
  end

  def run_deploy
    Dir.chdir(Rails.configuration.x.source_export_dir)
    terraform_apply
    Dir.chdir(Rails.root)
  end

  def terraform_apply
    RubyTerraform.apply(@apply_args)
  rescue RubyTerraform::Errors::ExecutionError
    nil
  end

  def write_output(log_file)
    # write the output of terraform apply
    # in STDOUT and file
    f = File.open(log_file, 'a')
    f.write(@apply_output)
    logger.info @apply_output
  end
end
