# frozen_string_literal: true

# Helpers used in resources page
module ResourcesHelper
  def ssh_cmd_bastion(outputs)
    private_key = outputs[:ssh_authorized_key_file].split('.')[0]
    "ssh #{outputs[:admin_user]}@#{outputs[:bastion_ip]} -i #{private_key}"
  end

  def ssh_cmd(outputs, output_name, index=0)
    private_key = outputs[:ssh_authorized_key_file].split('.')[0]
    private_address = outputs[output_name].split(',')[index]

    "ssh -o ProxyCommand=\"ssh -W %h:%p #{outputs[:admin_user]}@#{outputs[:bastion_ip]}"\
    " -i #{private_key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\""\
    " #{outputs[:admin_user]}@#{private_address} -i"\
    " #{private_key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
  end

  def ha_enabled?(outputs)
    outputs[:hana_ha_enabled] == true
  end
end
