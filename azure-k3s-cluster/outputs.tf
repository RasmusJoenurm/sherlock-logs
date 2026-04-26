output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.k8s.name
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "cluster_password" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].password
  sensitive = true
}

output "cluster_username" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].username
  sensitive = true
}

output "host" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].host
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config_raw
  sensitive = true
}

output "grafana_service" {
  value = "kube-prometheus-stack-grafana"
}

output "prometheus_service" {
  value = "kube-prometheus-stack-prometheus"
}

output "grafana_port_forward" {
  value = "kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n ${var.monitoring_namespace}"
}

output "prometheus_port_forward" {
  value = "kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n ${var.monitoring_namespace}"
}

output "vpn_gateway_public_ip" {
  value       = var.vpn_enabled ? azurerm_public_ip.vpn_gateway_pip[0].ip_address : null
  description = "Public IP of the Azure P2S VPN gateway"
}

output "vpn_gateway_name" {
  value       = var.vpn_enabled ? azurerm_virtual_network_gateway.p2s_gateway[0].name : null
  description = "Name of the Azure P2S VPN gateway"
}

output "dev_internal_edge_service" {
  value       = "myapp-dev-ilb.edge.svc.cluster.local"
  description = "Internal edge endpoint for dev (reachable from AKS VNet/VPN)"
}

output "public_dns_zone" {
  value       = var.enable_dns ? azurerm_dns_zone.public[0].name : null
  description = "Public Azure DNS zone name"
}

output "private_dns_zone" {
  value       = var.enable_dns ? azurerm_private_dns_zone.private[0].name : null
  description = "Private Azure DNS zone name"
}

output "private_dns_vnet_link" {
  value       = var.enable_dns && var.enable_private_dns_vnet_link && var.aks_vnet_name != "" && var.aks_vnet_resource_group_name != "" ? azurerm_private_dns_zone_virtual_network_link.aks[0].name : null
  description = "Private DNS zone VNet link name"
}

output "public_dns_record_names" {
  value       = keys(azurerm_dns_a_record.public_records)
  description = "Configured public DNS A-record host labels"
}

output "private_dns_record_names" {
  value       = keys(azurerm_private_dns_a_record.private_records)
  description = "Configured private DNS A-record host labels"
}

output "tls_key_vault_name" {
  value       = var.enable_tls_certificates ? azurerm_key_vault.tls[0].name : null
  description = "Key Vault used for TLS certificate management"
}

output "public_tls_certificate_name" {
  value       = var.enable_tls_certificates ? azurerm_key_vault_certificate.public_tls[0].name : null
  description = "Public endpoint TLS certificate name in Key Vault"
}

output "private_tls_certificate_name" {
  value       = var.enable_tls_certificates ? azurerm_key_vault_certificate.private_tls[0].name : null
  description = "Private endpoint TLS certificate name in Key Vault"
}

output "logs_storage_account_name" {
  value       = var.enable_logs_storage ? azurerm_storage_account.logs[0].name : null
  description = "Storage account name used for log archival"
}

output "logs_storage_container_name" {
  value       = var.enable_logs_storage ? azurerm_storage_container.logs[0].name : null
  description = "Blob container name used for log archival"
}


output "postgres_dev_fqdn" {
  value       = var.enable_managed_postgres ? azurerm_postgresql_flexible_server.dev[0].fqdn : null
  description = "Managed PostgreSQL dev server FQDN"
}

output "postgres_prod_fqdn" {
  value       = var.enable_managed_postgres ? azurerm_postgresql_flexible_server.prod[0].fqdn : null
  description = "Managed PostgreSQL prod server FQDN"
}

output "postgres_admin_username" {
  value       = var.enable_managed_postgres ? var.postgres_admin_username : null
  description = "Managed PostgreSQL administrator username"
}

output "postgres_dev_admin_password" {
  value       = var.enable_managed_postgres ? random_password.postgres_dev_admin_password[0].result : null
  description = "Managed PostgreSQL dev administrator password"
  sensitive   = true
}

output "postgres_prod_admin_password" {
  value       = var.enable_managed_postgres ? random_password.postgres_prod_admin_password[0].result : null
  description = "Managed PostgreSQL prod administrator password"
  sensitive   = true
}

