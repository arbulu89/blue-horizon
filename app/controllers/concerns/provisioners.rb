# frozen_string_literal: true

# module to manage all the provisioners logic in the deploy controller
module Provisioners
  include I18n

  # Interanl syntax used to identify the provisioner, E.g. hana_provision_1
  PROVISIONER_NAME_PATTERN = /(.*)_(\d+)/.freeze
  # EXCLUDED_PATTERN filters the terraform entries that won't go in the general
  # infrastructure creation bar, as they are the provisioning resources
  EXCLUDED_PATTERN = /.*\.(.*_provision).*\.provision\[(\d+)\]?/.freeze
  PROVISIONING_STATES = {
    not_started:    I18n.t('deploy.task_states.not_started'),
    initializing:   I18n.t('deploy.task_states.initializing'),
    configuring_os: I18n.t('deploy.task_states.configuring_os'),
    provisioning:   I18n.t('deploy.task_states.provisioning'),
    failed:         I18n.t('deploy.task_states.failed'),
    finished:       I18n.t('deploy.task_states.finished')
  }.freeze

  PROVISIONING_PATTERNS = {
    planned_states_count: Rails.configuration.x.provisioning_patterns['planned_states_count'],
    deployment_failed:    Rails.configuration.x.provisioning_patterns['deployment_failed'],
    configuring_os:       Rails.configuration.x.provisioning_patterns['configuring_os'],
    provisioning:         Rails.configuration.x.provisioning_patterns['provisioning'],
    # The next patterns are terraform/salt generic, so they are hardcoded here
    completed_state:      '.*Completed state.*',
    executing_mod_watch:  '.*Executing state.*mod_watch.*',
    retrying_state:       '.*State result does not match retry until value.*',
    creation_complete:    '.*Creation complete after.*',
    creating:             '.*Creating...$'
  }.freeze

  def find_provisioners
    provisioners = []
    terra = Terraform.new
    planned_resources = terra.get_planned_resources
    planned_resources.each do |resource|
      if (match = resource['address'].match(EXCLUDED_PATTERN))
        name = "#{match.captures[0]}_#{match.captures[1]}"
        provisioners.push(name)
      end
    end
    return provisioners
  end

  def init_provisioners(provisioners)
    KeyValue.set(:provisioners, provisioners.collect(&:to_s))
    provisioners.each do |provisioner|
      KeyValue.set(provisioner, :not_started)
    end
  end

  def provisioner_pattern(provisioner, pattern)
    data = provisioner.match(PROVISIONER_NAME_PATTERN)
    name = data.captures[0]
    index = data.captures[1]
    /.*\.#{name}.*\.provision\[#{index}\]#{pattern}/
  end

  def provisioner_get_completed_count(provisioner, content)
    salt_completed_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:completed_state]
    )
    total_completed = content.scan(salt_completed_pattern).size

    # States with mod.watch repeat run an additional states
    # that is not shown in the highstate output
    salt_mod_watch_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:executing_mod_watch]
    )
    mod_watch_completed = content.scan(salt_mod_watch_pattern).size

    # Retried states
    salt_retry_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:retrying_state]
    )
    salt_retries = content.scan(salt_retry_pattern).size
    return total_completed - mod_watch_completed - salt_retries
  end

  def provisioner_get_planned_states(provisioner, content)
    salt_states_count_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:planned_states_count]
    )
    return unless (match = content.match(salt_states_count_pattern))

    match.captures[0].to_i
  end

  def provisioner_check_completed(provisioner, content)
    completed_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:creation_complete]
    )
    content.scan(completed_pattern).size == 1
  end

  def provisioner_check_failed(provisioner, content)
    failed_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:deployment_failed]
    )
    content.scan(failed_pattern).size == 1
  end

  def wait_until_created(provisioner, content)
    salt_result_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:creating]
    )
    unless content.scan(salt_result_pattern).size.zero?
      KeyValue.set(provisioner, :initializing)
    end
  end

  def wait_until_configuring_os(provisioner, content)
    salt_result_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:configuring_os]
    )
    if content.scan(salt_result_pattern).size.zero?
      PROVISIONING_STATES[:initializing]
    else
      KeyValue.set(provisioner, :configuring_os)
      PROVISIONING_STATES[:configuring_os]
    end
  end

  def wait_until_provisioning(provisioner, content)
    salt_result_pattern = provisioner_pattern(
      provisioner, PROVISIONING_PATTERNS[:provisioning]
    )
    if content.scan(salt_result_pattern).size.zero?
      # This 5 is an arbitrary number to show some progress
      return PROVISIONING_STATES[:configuring_os], 5
    end

    KeyValue.set(provisioner, :provisioning)
    progress = get_provisioner_progress(provisioner, content)
    return PROVISIONING_STATES[:provisioning], progress
  end

  def get_provisioner_progress(provisioner, content)
    completed_count = provisioner_get_completed_count(provisioner, content)
    planned_states = provisioner_get_planned_states(provisioner, content)
    planned_states.nil? ? 0 : completed_count * 100 / planned_states
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/BlockLength
  def update_provisioners_progress(content)
    progress_data = {}
    return progress_data if content.blank?

    provisioners = KeyValue.get(:provisioners)
    provisioners.each do |provisioner|
      progress = 0
      result = true
      text = ''
      # When the provisioner is in finished, failed or not_started, the progress is not sent
      case KeyValue.get(provisioner)
      when :finished || :failed
        next
      when :not_started
        wait_until_created(provisioner, content)
        next
      when :initializing
        text = wait_until_configuring_os(provisioner, content)
      when :configuring_os
        text, progress = wait_until_provisioning(provisioner, content)
      when :provisioning
        progress = get_provisioner_progress(provisioner, content)
        text = PROVISIONING_STATES[:provisioning]
      end

      if provisioner_check_failed(provisioner, content)
        KeyValue.set(provisioner, :failed)
        text = PROVISIONING_STATES[:failed]
        result = false
      elsif provisioner_check_completed(provisioner, content)
        KeyValue.set(provisioner, :finished)
        text = PROVISIONING_STATES[:finished]
        progress = 100
      end

      progress_data[provisioner] = {
        progress: progress,
        text:     text,
        success:  result
      }
    end
    return progress_data
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/BlockLength
end
