# GitOps Galaxy

A GitOps-managed full-stack application on Azure Kubernetes Service (AKS) with production-grade monitoring, logging, alerting, and CI/CD.

## Architecture Overview

```
Internet → Azure LB (edge nginx) → Frontend (React/nginx) → Backend (Go/fiber) → PostgreSQL
                                                                   ↓
                                          /api/prom_metrics (Prometheus scrape target)

Prometheus ← kube-prometheus-stack (Node Exporter, cAdvisor, kube-state-metrics)
Grafana    ← Prometheus + Loki
Alertmanager → Discord (warnings + criticals)

Filebeat (DaemonSet) → Logstash → Elasticsearch → Kibana
                          ↓
                    Discord alerts on ERROR/CRITICAL log patterns
```

**Stack:**
- Infrastructure: AKS (Terraform), ArgoCD GitOps, Vault + External Secrets
- Application: React frontend, Go backend (fiber), PostgreSQL
- Monitoring: Prometheus + Grafana + Alertmanager (kube-prometheus-stack)
- Logging: Elasticsearch + Logstash + Filebeat + Kibana (ELK)
- Additional logging: Loki + Promtail (queryable from Grafana)

[Go fiber](https://github.com/gofiber/fiber) framework is used for backend.

## Usage

### Build images

```
docker compose build
```

### Run application

```
docker compose up -d
```

### Access frontend

```
http://localhost:3000
```

### Clean up

```
docker compose down -v
```

## Repository & CI/CD

**Source repository:** [https://github.com/RasmusJoenurm/sherlock-logs](https://github.com/RasmusJoenurm/sherlock-logs)

CI/CD runs via **GitHub Actions** (`.github/workflows/gitops-cicd.yaml`). On every push to `main`:
1. Builds frontend and backend Docker images → pushes to Docker Hub (`rasmusjoenurm/frontend`, `rasmusjoenurm/backend`)
2. Updates image tags in `azure-k3s-cluster/myapp/values-dev.yaml` and commits back
3. Logs into ArgoCD and syncs the root application → triggers deployment of all apps

ArgoCD watches this GitHub repository and automatically reconciles any manifest changes to the cluster.

> Note: the project submission copy lives at `https://gitea.kood.tech/rasmusjoenurm/sherlock-logs` but GitHub is the source of truth for development and CI/CD.

## Private Docker Hub setup

For GitHub Actions, add these repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

For Kubernetes image pulls, create a registry secret in each app namespace with the same name used in the Helm values file:

```bash
kubectl create secret docker-registry dockerhub-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKERHUB_USERNAME" \
  --docker-password="$DOCKERHUB_TOKEN" \
  --namespace app-dev
```

Repeat the command for `app-prod` and any other namespace that deploys the app.

## Secret management (HCP Vault + External Secrets)

Sensitive runtime values are pulled from Vault via External Secrets (no hardcoded PATs/passwords in manifests):

- app DB + JWT: `secret/data/gitops-galaxy/dev/database`, `secret/data/gitops-galaxy/prod/database`
- ArgoCD repo credentials: `secret/data/gitops-galaxy/argocd/repo`
- Elastic credentials: `secret/data/gitops-galaxy/elastic`

Prepare your local import file:

```bash
cp azure-k3s-cluster/scripts/hcp-vault-secrets.example.json azure-k3s-cluster/scripts/hcp-vault-secrets.json
```

Set Vault CLI environment and import all secrets:

```powershell
Copy-Item "azure-k3s-cluster/scripts/hcp-vault-secrets.example.json" "azure-k3s-cluster/scripts/hcp-vault-secrets.json"
$env:VAULT_ADDR = "<your-hcp-vault-address>"
$env:VAULT_TOKEN = "<your-hcp-vault-token>"
powershell -ExecutionPolicy Bypass -File "azure-k3s-cluster/scripts/import-hcp-vault-secrets.ps1"
```

Create/update the External Secrets operator token secret (namespace `external-secrets`):

```bash
kubectl apply -f azure-k3s-cluster/manifests/argocd/vault-token-secret.example.yaml
```

Then apply Terraform/Kubernetes manifests so `ExternalSecret` resources reconcile and create runtime Kubernetes secrets.

## Environment exposure model

- Production is exposed through the public edge load balancer service `myapp-prod-lb` in namespace `edge`.
- Development is exposed only through an internal Azure load balancer service `myapp-dev-ilb` in namespace `edge`.
- Frontend calls backend using `/api/*` paths (no `/dev` or `/prod` URL prefixes).

Apply edge routing manifests:

```bash
kubectl apply -f azure-k3s-cluster/manifests/myapp-dev-frontend-lb.yaml
```

## VPN (Azure P2S)

Terraform now includes optional VPN resources in `azure-k3s-cluster/network-vpn.tf`.

1. Find AKS VNet name and resource group (from the AKS node resource group).
2. Provide a root certificate public data value (`vpn_root_cert_public_data`).
3. Enable VPN and apply:

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="vpn_enabled=true" \
  -var="aks_vnet_name=<aks-vnet-name>" \
  -var="aks_vnet_resource_group_name=<aks-vnet-rg>" \
  -var="vpn_root_cert_public_data=<base64-x509-root-cert>"
```

After VPN connect, use the internal dev LB to access dev privately.

## Terraform remote state (Azure Storage)

Terraform backend is configured as `azurerm` in `azure-k3s-cluster/providers.tf`.

1. Copy `azure-k3s-cluster/backend.hcl.example` to a local file (for example `backend.hcl`) and fill in your storage values.
2. Initialize/migrate state:

```bash
terraform -chdir=azure-k3s-cluster init -backend-config=backend.hcl -migrate-state
```

This moves local state to Azure Storage so state is shared, lockable, and not committed to git.

## DNS zones (public + private)

Terraform creates both zones in Azure when `enable_dns=true`.

Apply (override with your domain names):

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="enable_dns=true" \
  -var="public_dns_zone_name=<your-public-domain>" \
  -var="private_dns_zone_name=<your-private-domain>"
```

If you also want the private zone linked to the AKS VNet, provide:

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="enable_dns=true" \
  -var="public_dns_zone_name=<your-public-domain>" \
  -var="private_dns_zone_name=<your-private-domain>" \
  -var="enable_private_dns_vnet_link=true" \
  -var="aks_vnet_name=<aks-vnet-name>" \
  -var="aks_vnet_resource_group_name=<aks-vnet-rg>"
```

Verify in Azure CLI:

```bash
az network dns zone list --output table
az network private-dns zone list --output table
```

## TLS certificates (Azure Certificate Management + Kubernetes)

TLS certs are managed in Azure Key Vault and consumed by edge nginx via Kubernetes TLS secrets:

- prod secret: `myapp-prod-tls`
- dev secret: `myapp-dev-tls`

Create/update TLS cert resources in Azure:

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="enable_tls_certificates=true" \
  -var="key_vault_name=<unique-keyvault-name>" \
  -var="public_tls_common_name=<public-fqdn>" \
  -var="private_tls_common_name=<private-fqdn>"
```

Verify certificates in cloud provider certificate service (Azure Key Vault):

```bash
az keyvault list --output table
az keyvault certificate list --vault-name <key_vault_name> --output table
```

Sync Key Vault certificates into Kubernetes TLS secrets for edge nginx:

```bash
powershell -ExecutionPolicy Bypass -File azure-k3s-cluster/scripts/sync-keyvault-tls-secrets.ps1 \
  -KeyVaultName <key_vault_name>
```

Apply edge routing (includes HTTPS listeners on 443):

```bash
kubectl apply -f azure-k3s-cluster/manifests/myapp-dev-frontend-lb.yaml
```

## Logging stack

Kubernetes logging in monitoring now includes Loki + Promtail (via Helm `loki-stack`) in addition to existing components. Grafana is configured with a Loki datasource so logs are queryable with LogQL.

Azure log archival storage is provisioned with Terraform as a dedicated storage account + private blob container (`logs`) and lifecycle retention policy.

Apply/update infrastructure:

```bash
terraform -chdir=azure-k3s-cluster apply
```

Optional logs storage overrides:

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="enable_logs_storage=true" \
  -var="logs_storage_account_name=<unique-storage-account-name>" \
  -var="logs_container_name=logs" \
  -var="logs_retention_days=30"
```

Verify storage resources:

```bash
az storage account list --resource-group <resource-group-name> --output table
az storage container list --account-name <logs_storage_account_name> --auth-mode login --output table
```

## Managed PostgreSQL (HA + PITR)

Terraform provisions Azure PostgreSQL Flexible Server for dev and prod in `azure-k3s-cluster/managed-postgres.tf`.

- Managed service: Azure PostgreSQL Flexible Server
- HA: enabled for prod (`high_availability`)
- PITR: enabled via automated backups and configurable retention days

Apply:

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="enable_managed_postgres=true"
```

Optional sizing/retention overrides:

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="enable_managed_postgres=true" \
  -var="postgres_prod_sku_name=GP_Standard_D4ds_v5" \
  -var="postgres_prod_backup_retention_days=30" \
  -var="postgres_dev_backup_retention_days=7"
```

Important: once managed DB is in use, remove/disable the in-cluster postgres app (`azure-k3s-cluster/manifests/argocd/apps/postgres-dev.yaml`) to avoid drift and confusion.

Check outputs:

```bash
terraform -chdir=azure-k3s-cluster output postgres_dev_fqdn
terraform -chdir=azure-k3s-cluster output postgres_prod_fqdn
```

## PostgreSQL Prometheus exporter

Terraform deploys `postgres-exporter` in `monitoring` when both managed PostgreSQL and exporter are enabled.

Apply:

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var="enable_managed_postgres=true" \
  -var="enable_postgres_exporter=true"
```

Verify:

```bash
kubectl get pods -n monitoring -l app=postgres-exporter
kubectl get svc -n monitoring postgres-exporter
kubectl get servicemonitor -n monitoring postgres-exporter
```

## Endpoints

| endpoint      | method | body                                           | description       |
| ------------- | ------ | ---------------------------------------------- | ----------------- |
| /api/ping     | GET    |                                                | ping server       |
| /api/session  | GET    |                                                | get user session  |
| /api/login    | POST   | { email String, password String }              | login user        |
| /api/register | POST   | { email String, password String, name String } | register new user |
|               |        |                                                |                   |

## Extra-points compliance checklist

- Increased security: only production sample application is publicly exposed (`myapp-prod-lb`). Dev is internal-only (`myapp-dev-ilb`) and tooling ingress is disabled by default.
- VPN access to private resources: Azure P2S VPN is provisioned via `azure-k3s-cluster/network-vpn.tf`.
- Private DNS zone for private resources: Azure private DNS zone + optional AKS VNet link + configurable A records are provisioned in `azure-k3s-cluster/dns.tf`.

### Suggested DNS record apply example

```bash
terraform -chdir=azure-k3s-cluster apply \
  -var='public_dns_zone_name=example.com' \
  -var='private_dns_zone_name=test-private.example.com' \
  -var='public_dns_a_records={"www"=["<prod_public_lb_ip>"]}' \
  -var='private_dns_a_records={"argocd"=["<dev_internal_lb_ip>"],"grafana"=["<dev_internal_lb_ip>"]}'
```

### Verification commands

```bash
# Public/Private zones exist
az network dns zone list --output table
az network private-dns zone list --output table

# Certificates exist in Azure certificate management service (Key Vault)
az keyvault certificate list --vault-name <key_vault_name> --output table

# Kubernetes exposure check
kubectl get svc -n edge

# DNS resolution over VPN (example)
nslookup argocd.test-private.example.com
nslookup grafana.test-private.example.com
```

### Documentation / resilience notes

- IaC automation level: infrastructure for AKS, VPN, DNS, TLS certificates, managed PostgreSQL HA/PITR, log storage, and monitoring are automated with Terraform.
- CI/CD automation level: GitHub Actions + Argo CD sync are present; further automation can include automated TLS secret sync and private DNS record updates from LB IP outputs.
- Resilience and fault tolerance: production PostgreSQL uses HA mode + backup retention for PITR; Terraform-managed log archival retention and VPN-based private access reduce operational risk.

---

## Monitoring Stack

### Access Grafana

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# Open http://localhost:3000, credentials from Vault or terraform output
```

### Access Prometheus

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# Open http://localhost:9090
```

### Grafana Dashboards

Three dashboards are provisioned automatically via ConfigMaps (label `grafana_dashboard: "1"`):

| Dashboard | Description | Key metrics |
|-----------|-------------|-------------|
| **VM Performance** | Node CPU %, memory %, disk I/O, network traffic | `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_disk_*`, `node_network_*` |
| **Docker Container Performance** | Container CPU/memory, restart counts, memory % of limit | `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`, `kube_pod_container_status_restarts_total` |
| **Application Performance** | HTTP request rate, error rate, p50/p95/p99 latency, custom registration counter | `http_requests_total`, `http_request_duration_seconds`, `active_user_registrations_total` |

### Application Metrics Endpoint

The backend exposes Prometheus metrics at `/api/prom_metrics`. Scraped every 15s by the backend ServiceMonitor.

Custom metric: `active_user_registrations_total` — cumulative count of successful user registrations.

---

## Logging Stack

### Log Flow

```
Container stdout/stderr
        ↓
Filebeat (DaemonSet, one per node)
        ↓
Logstash (elastic namespace, port 5044)
  - Filters: adds "alert" tag to ERROR/Exception/CRITICAL/500/502/503/504 messages
  - Sends alert-tagged messages to Discord webhook
        ↓
Elasticsearch (elastic namespace)
        ↓
Kibana (elastic namespace)
```

### Access Kibana

```bash
kubectl port-forward svc/kibana-kibana 5601:5601 -n elastic
# Open https://localhost:5601, credentials from elastic-credentials secret
kubectl get secret elastic-credentials -n elastic -o jsonpath='{.data.username}' | base64 -d
kubectl get secret elastic-credentials -n elastic -o jsonpath='{.data.password}' | base64 -d
```

### Kibana Dashboards

Three dashboards are imported automatically by the `kibana-dashboard-import` Job (runs as ArgoCD PostSync hook):

| Dashboard | Index pattern | Description |
|-----------|---------------|-------------|
| **System Logs Dashboard** | `logstash-*` | Syslog and dmesg logs from all cluster nodes (filter: `log_type: system`) |
| **Application Logs Dashboard** | `logstash-*` | Backend and frontend container logs, error counts (filter: container name backend/frontend) |
| **Docker Logs Dashboard** | `logstash-*` | All container stdout/stderr, grouped by namespace and pod |

To manually re-import dashboards:

```bash
kubectl create job --from=job/kibana-dashboard-import kibana-import-$(date +%s) -n elastic
```

### Logstash Discord Alerts

Logstash sends a Discord notification when log messages contain: `ERROR`, `Exception`, `CRITICAL`, `Failed password`, `authentication failed`, or HTTP 500/502/503/504 status codes.

Setup: store your Discord webhook URL in Vault:
```bash
vault kv put secret/gitops-galaxy/discord webhook_url="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
```
Or create the secret manually:
```bash
kubectl create secret generic logstash-alert-webhook \
  --from-literal=url="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN" \
  -n elastic
```

---

## Alerts

All alerts send to Discord via Alertmanager. Configured in `azure-k3s-cluster/values/kube-prometheus-stack-values.yaml`.

### Mandatory Threshold Alerts

| Alert | Condition | Severity | Simulate |
|-------|-----------|----------|---------|
| NodeCPUHighUsage | CPU > 80% for 5 min | critical | `stress-ng --cpu 8 --timeout 360s` |
| NodeDiskLow | Disk < 20% free for 5 min | critical | `fallocate -l 10G large_file.img` |
| NodeMemoryHighUsage | Memory > 90% for 5 min | critical | `stress-ng --vm 2 --vm-bytes 80% --timeout 360s` |
| ContainerRestartingFrequently | Restarts > 3 in 15 min | warning | `docker run --restart=always ubuntu bash -c "sleep 10; exit 1"` |
| ContainerMemoryLimitHigh | Memory > 80% of limit for 5 min | warning | `docker run -m 512m ubuntu bash -c "stress-ng --vm 1 --vm-bytes 450M --timeout 360s"` |
| InstanceDown | Any scrape target unreachable for 1 min | critical | `sudo ifconfig eth0 down` |
| ElasticsearchClusterNotHealthy | ES cluster yellow or red for 5 min | critical | Stop one ES node in a multi-node cluster |

### Advanced Alerts (trend + combination)

| Alert | Condition | Severity |
|-------|-----------|----------|
| BackendHighLatencyP95 | p95 latency > 1s for 5 min | warning |
| BackendErrorRateHigh | 5xx error rate > 5% for 3 min | warning |
| PodMemoryPressureAndRestarts | Memory > 85% of limit AND > 2 restarts in 10 min | critical |
| SustainedPodCPUHigh | Pod CPU > 0.8 cores for 10 min | warning |

