# frozen_string_literal: true

# module to manage all the provisioners logic in the deploy controller
module Provisioners
  PROVISIONER_NAME_PATTERN = /(.*)_(\d+)/.freeze
  EXCLUDED_PATTERN = /.*\.(.*_provision).*\.provision\[(\d+)\]?/.freeze
  PROVISIONING_STATES = {
    not_started:    'Not started',
    initializing:   'Initializing machine...',
    configuring_os: 'Configuring operative system...',
    provisioning:   'Provisioning machine...',
    failed:         'Failed',
    finished:       'Finished'
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
      provisioner, '.*Completed state.*'
    )
    total_completed = content.scan(salt_completed_pattern).size

    # States with mod.watch repeat run an additional states
    # that is not shown in the highstate output
    salt_mod_watch_pattern = provisioner_pattern(
      provisioner, '.*Executing state.*mod_watch.*'
    )
    mod_watch_completed = content.scan(salt_mod_watch_pattern).size

    # Retried states
    salt_retry_pattern = provisioner_pattern(
      provisioner, '.*State result does not match retry until value.*'
    )
    salt_retries = content.scan(salt_retry_pattern).size
    return total_completed - mod_watch_completed - salt_retries
  end

  def provisioner_get_planned_states(provisioner, content)
    salt_states_count_pattern = provisioner_pattern(
      provisioner, '.*Total planned states count: (\d+)$'
    )
    return unless (match = content.match(salt_states_count_pattern))

    match.captures[0].to_i
  end

  def provisioner_check_completed(provisioner, content)
    completed_pattern = provisioner_pattern(
      provisioner, '.*Creation complete after.*'
    )
    content.scan(completed_pattern).size == 1
  end

  def provisioner_check_failed(provisioner, content)
    failed_pattern = provisioner_pattern(
      provisioner, '.*::Deployment failed$'
    )
    content.scan(failed_pattern).size == 1
  end

  def wait_until_created(provisioner, content)
    salt_result_pattern = provisioner_pattern(
      provisioner, '.*Creating...$'
    )
    if content.scan(salt_result_pattern).size.zero?
      PROVISIONING_STATES[:not_started]
    else
      KeyValue.set(provisioner, :initializing)
      PROVISIONING_STATES[:initializing]
    end
  end

  def wait_until_configuring_os(provisioner, content)
    salt_result_pattern = provisioner_pattern(
      provisioner, '.*Configuring operative system...$'
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
      provisioner, '.*Provisioning system...$'
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

  def update_provisioners_progress(content)
    progress_data = {}
    return progress_data if content.blank?

    provisioners = KeyValue.get(:provisioners)
    provisioners.each do |provisioner|
      progress = 0
      result = true
      text = ''
      case KeyValue.get(provisioner)
      when :finished || :failed
        next
      when :not_started
        text = wait_until_created(provisioner, content)
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
end
