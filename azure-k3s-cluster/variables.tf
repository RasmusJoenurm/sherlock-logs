variable "resource_group_location" {
  type        = string
  default     = "swedencentral"
  description = "Location of the resource group."
}


variable "resource_group_name" {
  type    = string
  default = "rg-aware-moray"
}

variable "cluster_name" {
  type    = string
  default = "cluster-maximum-snail"
}

variable "node_count" {
  type        = number
  description = "The initial quantity of nodes for the node pool."
  default     = 1
}
variable "system_node_max" {
  type    = number
  default = 2 # max nodes when using autoscaling
}

variable "msi_id" {
  type        = string
  description = "The Managed Service Identity ID. Set this value if you're running this example using Managed Identity as the authentication method."
  default     = null
}

variable "username" {
  type        = string
  description = "The admin username for the new cluster."
  default     = "azureadmin"
}

variable "monitoring_namespace" {
  type    = string
  default = "monitoring"
}

variable "grafana_admin_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "grafana_host" {
  type    = string
  default = ""
}
variable "kibana_host" {
  type    = string
  default = ""
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for Alertmanager notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vpn_enabled" {
  description = "Enable Point-to-Site VPN resources and AKS VNet peering"
  type        = bool
  default     = false
}

variable "aks_vnet_name" {
  description = "Existing AKS VNet name (usually in the AKS managed node resource group)"
  type        = string
  default     = ""
}

variable "aks_vnet_resource_group_name" {
  description = "Resource group name of the existing AKS VNet"
  type        = string
  default     = ""
}

variable "vpn_vnet_address_space" {
  description = "Address space for the VPN VNet"
  type        = list(string)
  default     = ["10.250.0.0/16"]
}

variable "vpn_gateway_subnet_prefixes" {
  description = "GatewaySubnet CIDR for the VPN VNet"
  type        = list(string)
  default     = ["10.250.255.0/27"]
}

variable "vpn_client_address_space" {
  description = "Client address space allocated to VPN users"
  type        = list(string)
  default     = ["172.16.201.0/24"]
}

variable "vpn_gateway_sku" {
  description = "Azure VPN gateway SKU"
  type        = string
  default     = "VpnGw1"
}

variable "vpn_root_cert_public_data" {
  description = "Root certificate public data (Base64 X.509) used by P2S clients"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_dns" {
  description = "Create public and private DNS zones"
  type        = bool
  default     = true
}

variable "public_dns_zone_name" {
  description = "Public DNS zone name (for example: example.com)"
  type        = string
  default     = "gitops-galaxy.example.com"
}

variable "private_dns_zone_name" {
  description = "Private DNS zone name"
  type        = string
  default     = "internal.gitops-galaxy.local"
}

variable "enable_private_dns_vnet_link" {
  description = "Link private DNS zone to AKS VNet when VNet variables are provided"
  type        = bool
  default     = true
}

variable "public_dns_a_records" {
  description = "Map of public DNS A records. Key is hostname label, value is list of IPv4 addresses."
  type        = map(list(string))
  default     = {}
}

variable "private_dns_a_records" {
  description = "Map of private DNS A records. Key is hostname label, value is list of IPv4 addresses."
  type        = map(list(string))
  default     = {}
}

variable "enable_tls_certificates" {
  description = "Create TLS certificates in Azure Key Vault for public and private edge endpoints"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Key Vault name used for TLS certificate management"
  type        = string
  default     = "gitopsgalaxytlskv"
}

variable "public_tls_common_name" {
  description = "Public certificate common name"
  type        = string
  default     = "www.gitops-galaxy.example.com"
}

variable "private_tls_common_name" {
  description = "Private certificate common name"
  type        = string
  default     = "dev.internal.gitops-galaxy.local"
}

variable "enable_postgres_exporter" {
  description = "Deploy postgres-exporter and ServiceMonitor for Prometheus"
  type        = bool
  default     = true
}

variable "enable_logs_storage" {
  description = "Create dedicated storage account/container for logs"
  type        = bool
  default     = true
}

variable "logs_storage_account_name" {
  description = "Optional explicit storage account name for logs (must be globally unique, lowercase, 3-24 chars). Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "logs_container_name" {
  description = "Blob container name used for log archival"
  type        = string
  default     = "logs"
}

variable "logs_retention_days" {
  description = "Retention period in days for blobs in the logs container"
  type        = number
  default     = 30
}

variable "enable_managed_postgres" {
  description = "Create managed Azure PostgreSQL Flexible Servers for dev and prod"
  type        = bool
  default     = true
}

variable "postgres_admin_username" {
  description = "Administrator username for managed PostgreSQL"
  type        = string
  default     = "pgadmin"
}

variable "postgres_version" {
  description = "PostgreSQL version for managed servers"
  type        = string
  default     = "16"
}

variable "postgres_location" {
  description = "Azure region for managed PostgreSQL Flexible Server. Use a region allowed for your subscription."
  type        = string
  default     = "swedencentral"
}

variable "postgres_dev_db_name" {
  description = "Database name for dev managed PostgreSQL"
  type        = string
  default     = "gitops"
}

variable "postgres_prod_db_name" {
  description = "Database name for prod managed PostgreSQL"
  type        = string
  default     = "gitops"
}

variable "postgres_dev_sku_name" {
  description = "SKU for dev managed PostgreSQL"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgres_prod_sku_name" {
  description = "SKU for prod managed PostgreSQL"
  type        = string
  default     = "GP_Standard_D4ds_v5"
}

variable "postgres_dev_storage_mb" {
  description = "Storage size (MB) for dev managed PostgreSQL"
  type        = number
  default     = 32768
}

variable "postgres_prod_storage_mb" {
  description = "Storage size (MB) for prod managed PostgreSQL"
  type        = number
  default     = 131072
}

variable "postgres_dev_backup_retention_days" {
  description = "Backup retention days for dev (enables PITR window)"
  type        = number
  default     = 7
}

variable "postgres_prod_backup_retention_days" {
  description = "Backup retention days for prod (enables PITR window)"
  type        = number
  default     = 30
}

variable "postgres_public_network_access_enabled" {
  description = "Whether managed PostgreSQL public network access is enabled"
  type        = bool
  default     = true
}

variable "postgres_prod_ha_mode" {
  description = "HA mode for prod managed PostgreSQL"
  type        = string
  default     = "SameZone"
}

variable "postgres_prod_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups for prod managed PostgreSQL"
  type        = bool
  default     = false
}

