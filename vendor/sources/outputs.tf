output "admin_user" {
  value = var.os_admnistrator_name
}

output "bastion_ip" {
  value = module.bluehorizon.bastion_public_ip
}

output "monitoring_ip" {
  value = module.bluehorizon.monitoring_ip
}

output "iscsi_ip" {
  value = module.bluehorizon.iscsi_srv_ip
}

output "hana_ips" {
  value = join(",", module.bluehorizon.cluster_nodes_ip)
}

output "hana_ip" {
  value = module.bluehorizon.hana_ip
}


output "ssh_authorized_key_file" {
  value = var.ssh_authorized_key_file
}

output "hana_ha_enabled" {
  value = var.hana_ha_enabled
}

output "sid" {
  value = var.system_identifier
}

output "instance_number" {
  value = var.instance_number
}

data "azurerm_subscription" "current" {
}

output "resource_group_url" {
  value = "https://portal.azure.com/#@SUSERDBillingsuse.onmicrosoft.com/resource${data.azurerm_subscription.current.id}/resourceGroups/rg-ha-sap-${var.deployment_name}/overview"
}
