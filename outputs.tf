output "ssh_client_public_ip" {
  value = "ssh adminuser@${azurerm_public_ip.client.ip_address}"
}

# output "tfe_public_ip_lb" {
#   value = azurerm_public_ip.tfe_lb.ip_address
# }

output "tfe_appplication" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}"
}

# output "ssh_tfe_server" {
#   value = "ssh -o IdentitiesOnly=yes -i tfesshkey.pem adminuser@${var.dns_hostname}.${var.dns_zonename}"
# }

#ssh -o IdentitiesOnly=yes -i tfesshkey.pem -J adminuser@20.82.163.60 adminuser@10.214.2.5

output "ssh_tfe_nodes" {
  value = [for k, v in data.azurerm_virtual_machine_scale_set.tfe.instances : "node-${k}: ssh -J adminuser@${azurerm_public_ip.client.ip_address} adminuser@${v.private_ip_address}"]
}

# output "release_sequence" {
#   description = "Installed release number of TFE."
#   value       = var.tfe_release
# }