# frozen_string_literal: true

require 'ruby_terraform'

class DeploysController < ApplicationController
  include Provisioners
  include I18n

  APPLY_ACTION = 'apply'
  DESTROY_ACTION = 'destroy'

  def show
    @provisioners = find_provisioners
    init_provisioners(@provisioners)
  end

  def update
    logger.info('Calling run_deploy')
    @apply_args = {
      directory:    Rails.configuration.x.source_export_dir,
      auto_approve: true,
      no_color:     true
    }
    terra = Terraform.new
    planned_resources = terra.get_planned_resources(
      Provisioners::EXCLUDED_PATTERN
    ).count
    KeyValue.set(:planned_resources_count, planned_resources)
    # +1 adds the infrastructure creation that happens always
    KeyValue.set(:total_steps, find_provisioners.size + 1)
    KeyValue.set(:completed_steps, 0)
    KeyValue.set(:resource_creation_state, :not_started)
    KeyValue.set(:deploy_action, APPLY_ACTION)
    result = terra.apply(@apply_args)
    logger.info('Deploy finished.')
    show_flash(result)
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def send_current_status
    if Terraform.stderr.is_a?(StringIO) && !Terraform.stderr.string.empty?
      error = Terraform.stderr.string
      content = error
      success = false
      write_output(content, success)
    elsif Terraform.stdout.is_a?(StringIO)
      @apply_output = Terraform.stdout.string
      content = @apply_output
      success = content.match(/(Apply complete!|Destroy complete!)/)
    end

    action = KeyValue.get(:deploy_action)
    progress = {}
    if action == APPLY_ACTION && Terraform.stdout.is_a?(StringIO)
      progress = update_progress(Terraform.stdout.string, error)
    end

    if success
      KeyValue.set(:deployment_finished, true) if action == APPLY_ACTION
      write_output(content, success)
      set_default_logger_config
    end
    html = (render_to_string partial: 'output.html.haml')

    respond_to do |format|
      format.json do
        render json: { new_html: html, progress: progress,
                       success: success, error: error }
      end
    end
    return
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def destroy
    logger.info('Calling destroy')
    KeyValue.set(:deploy_action, DESTROY_ACTION)
    KeyValue.set(:deployment_finished, nil)
    result = Terraform.new.destroy
    cleanup if result.nil?
    logger.info('Destroy finished')
    show_flash(result)
  end

  private

  def show_flash(result)
    action = KeyValue.get(:deploy_action)
    @flash_data = if result.nil?
      {
        message: I18n.t("flash.deploy.#{action}_success"),
        state:   'alert-success'
      }
    else
      {
        message: I18n.t("flash.deploy.#{action}_error"),
        state:   'alert-danger'
      }
    end
    respond_to do |format|
      format.json { result }
      format.js { render layout: false, action: 'flash' }
    end
  end

  def cleanup
    statefile = Rails.configuration.x.source_export_dir.join(Terraform.statefilename)
    Rails.logger.debug("cleaning up #{statefile}")
    File.delete(statefile) if File.exist?(statefile)
  end

  def set_default_logger_config
    RubyTerraform.configuration.stdout = RubyTerraform.configuration.logger
    RubyTerraform.configuration.stderr = RubyTerraform.configuration.logger
  end

  def write_output(content, success)
    # write the output of terraform apply
    # in STDOUT and file
    File.open(
      Rails.configuration.x.terraform_log_filename, 'a'
    ) { |file| file.write(content) }
    if success
      logger.info content
    else
      logger.error content
    end
  end

  def update_terraform_progress(content, error)
    progress = {}
    state = KeyValue.get(:resource_creation_state)
    return progress if state == :finished

    created_resources = content.scan(/Creation complete after/).size
    planned_resources_count = KeyValue.get(:planned_resources_count)

    progress_number = if created_resources >= planned_resources_count
      KeyValue.set(:resource_creation_state, :finished)
      100
    else
      created_resources * 100 / planned_resources_count
    end

    text = if error.present?
      t('deploy.task_states.failed')
    elsif created_resources >= planned_resources_count
      t('deploy.task_states.finished')
    else
      t('deploy.task_states.creating')
    end

    progress['infra-task'] = {
      progress: progress_number,
      text:     text,
      success:  error.nil? ? true : false
    }
    return progress
  end

  def update_total_progress(tasks_progress, error)
    # The methods depends on that once the task is finished in any of the tasks, the
    # data is not sent again
    total_steps = KeyValue.get(:total_steps).to_i
    completed_steps = KeyValue.get(:completed_steps).to_i
    tasks_progress.each_value do |task|
      if task[:text] == Provisioners::PROVISIONING_STATES[:finished]
        completed_steps += 1
        KeyValue.set(:completed_steps, completed_steps)
      end
    end

    text = if error.present?
      t('deploy.failed')
    elsif total_steps == completed_steps
      t('deploy.finished')
    else
      t('deploy.in_progress')
    end

    progress = {
      progress: completed_steps * 100 / total_steps,
      text:     text
    }
    return progress
  end

  def update_progress(content, error)
    progress = {}
    return progress if content.blank?

    terraform_progress = update_terraform_progress(content, error)
    tasks_progress = update_provisioners_progress(content)
    tasks_progress.merge!(terraform_progress)

    progress['tasks_progress'] = tasks_progress
    progress['total_progress'] = update_total_progress(tasks_progress, error)
    return progress
  end
end
