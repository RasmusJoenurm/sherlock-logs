# Sherlock Logs

A full-stack application running on Azure Kubernetes Service with a complete observability stack — metrics, logs, dashboards, and alerting — all managed through GitOps.

Fair warning up front: this project isn't a simple `docker compose up`. It spans Terraform, AKS, ArgoCD, Prometheus, Grafana, the ELK stack, and a Go/React application. If you're willing to work through it, everything below will get you there.

---

## What's in here

The core idea is a Go + React app deployed across three environments (dev, staging, prod) on a single AKS cluster, with a full observability layer bolted on:

- **Metrics path:** The app exposes a Prometheus endpoint. Prometheus scrapes it along with node and container metrics from the cluster. Grafana visualizes everything.
- **Logging path:** Filebeat runs as a DaemonSet and ships all container logs to Logstash, which filters them and forwards to Elasticsearch. Kibana sits on top for querying and dashboards.
- **Alerting:** Prometheus rules fire to Alertmanager, which sends Discord notifications. Logstash independently sends Discord messages when it sees ERROR/CRITICAL patterns in logs.
- **GitOps:** ArgoCD watches this repository. Any change pushed to `main` gets reconciled to the cluster automatically. CI/CD builds images on GitHub Actions and triggers ArgoCD syncs.

---

## Data flow

```
                          ┌─────────────────────────────────────────────────┐
                          │                   AKS Cluster                   │
                          │                                                  │
  GitHub ──push──▶ ArgoCD │  reconciles ──▶ Deployments / Services / CRDs  │
                          │                                                  │
  GitHub Actions          │  ┌─────────────────────────────────────────────┐│
  (build + tag) ──────────┼─▶│  App (Go backend + React frontend)          ││
                          │  │  ├── /api/prom_metrics  ◀── scrape           ││
                          │  │  └── stdout/stderr logs ──▶ Filebeat         ││
                          │  └─────────────────────────────────────────────┘│
                          │                   │              │               │
                          │           METRICS PATH     LOGGING PATH          │
                          │                   │              │               │
                          │                   ▼              ▼               │
                          │  ┌──────────────────┐   ┌──────────────────┐    │
                          │  │   Prometheus      │   │    Logstash      │    │
                          │  │  (+ node-exporter │   │  filter: ERROR/  │    │
                          │  │     + cAdvisor)   │   │  CRITICAL/5xx    │    │
                          │  └────────┬──────────┘   └───────┬──────────┘    │
                          │           │                       │              │
                          │     ┌─────┴──────┐        ┌──────┴──────┐       │
                          │     │  Grafana   │        │Elasticsearch│       │
                          │     │ dashboards │        │   + Kibana  │       │
                          │     └─────┬──────┘        └──────┬──────┘       │
                          │           │                       │              │
                          │     ┌─────┴──────┐               │ alert tag    │
                          │     │Alertmanager│               │              │
                          │     └─────┬──────┘               │              │
                          └───────────┼───────────────────────┼─────────────┘
                                      │                       │
                                      ▼                       ▼
                                  Discord                  Discord
                               (threshold alerts)      (log pattern alerts)
```

---

## Prerequisites

You'll need these installed locally:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) — logged in with `az login`
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [Helm](https://helm.sh/docs/intro/install/)
- An Azure subscription with ~€30 budget if you want to run it for a couple of days
- A Discord webhook URL for alerts (create one under Server Settings → Integrations)
- A Docker Hub account (for CI/CD to push images)

---

## Setting it up

### 1. Provision the infrastructure

The AKS cluster, PostgreSQL servers, storage, and Key Vault are all managed with Terraform.

```bash
cd azure-k3s-cluster

# Set up remote state backend (Azure Storage)
cp backend.hcl.example backend.hcl
# Fill in your storage account details in backend.hcl, then:
terraform init -backend-config=backend.hcl

# Review what Terraform will create
terraform plan -var="discord_webhook_url=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"

# Apply — this takes about 10 minutes
terraform apply -var="discord_webhook_url=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
```

Once it completes, grab your kubeconfig:

```bash
az aks get-credentials --resource-group rg-aware-moray --name cluster-maximum-snail
kubectl get nodes  # wait until status is Ready
```

### 2. Connect to ArgoCD

ArgoCD is deployed inside the cluster without a public LoadBalancer, so you access it through a port-forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

argocd login localhost:8080 --insecure --username admin \
  --password "$(kubectl get secret argocd-initial-admin-secret -n argocd \
    -o jsonpath='{.data.password}' | base64 -d)"
```

Keep the port-forward running in the background while you work.

### 3. Create one-time secrets

These secrets are not stored in git. You need to create them once per cluster. If you destroy and recreate the cluster, run these again.

**Alertmanager Discord config** (pulls the webhook URL from the Terraform-created secret):

```bash
bash scripts/create-alertmanager-secret.sh
```

**Elasticsearch credentials** (for Logstash and the ES exporter to authenticate):

```bash
ELASTIC_PASSWORD=$(kubectl get secret elasticsearch-master-credentials -n elastic \
  -o jsonpath='{.data.password}' | base64 -d)

kubectl create secret generic elastic-credentials \
  --from-literal=username=elastic \
  --from-literal=password="$ELASTIC_PASSWORD" \
  -n elastic
```

**Fix Elasticsearch replica count** — single-node ES goes yellow when any index has replicas > 0, which blocks the readiness probe. Run this once after ES is up:

```bash
kubectl exec -n elastic elasticsearch-master-0 -- curl -sk \
  -u "elastic:$ELASTIC_PASSWORD" \
  -X PUT "https://localhost:9200/*/_settings" \
  -H "Content-Type: application/json" \
  -d '{"index.number_of_replicas":0}'

# Also set a default template so new indices don't create replicas either:
kubectl exec -n elastic elasticsearch-master-0 -- curl -sk \
  -u "elastic:$ELASTIC_PASSWORD" \
  -X PUT "https://localhost:9200/_template/no-replicas" \
  -H "Content-Type: application/json" \
  -d '{"index_patterns":["*"],"settings":{"number_of_replicas":0}}'
```

### 4. Sync the apps

```bash
argocd app sync argocd-bootstrap
sleep 30
argocd app sync kube-prometheus-stack
argocd app sync kibana monitoring-addons elasticsearch-exporter
```

> **Note on Kibana:** The 8.5.1 Helm chart has an unfixed bug where the pre-install hook fails on re-syncs with a 409 conflict. The Kibana ArgoCD app intentionally has auto-sync disabled to prevent this loop. Kibana only needs a manual sync on first deploy — after that it stays up.

Check that everything came up:

```bash
argocd app list
kubectl get pods -n monitoring
kubectl get pods -n elastic
```

All pods should be `Running`. The `kibana-dashboard-import` job should show `Completed`.

### 5. Set up Docker Hub and GitHub Actions

For CI/CD to work, add these secrets to your GitHub repository (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `ARGOCD_SERVER` | ArgoCD address (e.g. `localhost:8080` if using port-forward, or use an LB IP if you configure one) |
| `ARGOCD_AUTH_TOKEN` | ArgoCD API token |

Also create the image pull secret in each app namespace:

```bash
for ns in app-dev app-staging app-prod; do
  kubectl create secret docker-registry dockerhub-regcred \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="YOUR_DOCKERHUB_USERNAME" \
    --docker-password="YOUR_DOCKERHUB_TOKEN" \
    --namespace "$ns"
done
```

---

## Accessing the tools

Everything runs inside the cluster — use port-forwards to reach the UIs locally.

### Grafana

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
```

Open `http://localhost:3000` — username `admin`, password `gitopsgalaxygrafana`.

Three dashboards are provisioned automatically:

| Dashboard | What it shows |
|-----------|---------------|
| **VM Performance** | Node CPU %, memory %, disk I/O, network traffic |
| **Docker Container Performance** | Container CPU/memory usage, restart counts, memory % of limit |
| **Application Performance** | HTTP request rate, error rate, p50/p95/p99 latency, `active_user_registrations_total` |

### Prometheus

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
```

Open `http://localhost:9090`. The Alerts tab shows all configured rules. The custom application metric lives at:

```
active_user_registrations_total
```

### Kibana

```bash
kubectl port-forward svc/kibana-kibana 5601:5601 -n elastic
```

Open `http://localhost:5601` — username `elastic`, password from:

```bash
kubectl get secret elasticsearch-master-credentials -n elastic \
  -o jsonpath='{.data.password}' | base64 -d
```

Three dashboards are imported automatically:

| Dashboard | Index pattern | What it shows |
|-----------|---------------|---------------|
| **System Logs Dashboard** | `logstash-*` | Node-level system logs |
| **Application Logs Dashboard** | `logstash-*` | Backend and frontend container logs |
| **Docker Logs Dashboard** | `logstash-*` | All container stdout/stderr by namespace and pod |

---

## Alerts

All threshold alerts go to Discord via Alertmanager. Logstash sends a separate notification when it sees `ERROR`, `Exception`, `CRITICAL`, `Failed password`, `authentication failed`, or HTTP 5xx in any container log.

### Threshold alerts (Prometheus → Alertmanager → Discord)

| Alert | Trigger | Severity |
|-------|---------|----------|
| NodeCPUHighUsage | CPU > 80% for 5 minutes | critical |
| NodeMemoryHighUsage | Memory > 90% for 5 minutes | critical |
| NodeDiskLow | Disk < 20% free for 5 minutes | critical |
| ContainerRestartingFrequently | Container restarts > 3 in 15 minutes | warning |
| ContainerMemoryLimitHigh | Container memory > 80% of its limit | warning |
| InstanceDown | Any scrape target unreachable for 1 minute | critical |
| ElasticsearchClusterNotHealthy | ES cluster yellow or red for 5 minutes | critical |

To simulate CPU pressure for testing:

```bash
kubectl run stress-test --image=progrium/stress --restart=Never -- \
  --cpu 4 --timeout 360s
```

### Advanced alerts (trend + combination)

| Alert | What triggers it |
|-------|-----------------|
| BackendHighLatencyP95 | p95 response time > 1s for 5 minutes |
| BackendErrorRateHigh | 5xx error rate > 5% for 3 minutes |
| PodMemoryPressureAndRestarts | Pod memory > 85% of limit AND > 2 restarts in 10 minutes |
| SustainedPodCPUHigh | Pod CPU > 0.8 cores sustained for 10 minutes |

---

## Application endpoints

The Go backend exposes:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/ping` | GET | Health check |
| `/api/session` | GET | Get current session |
| `/api/login` | POST | Login with `{email, password}` |
| `/api/register` | POST | Register with `{email, password, name}` |
| `/api/prom_metrics` | GET | Prometheus metrics scrape target |

---

## Cost and teardown

Running the full stack costs roughly €16/day on Azure. Stop everything before closing your laptop:

```bash
az postgres flexible-server stop --resource-group rg-aware-moray --name cluster-maximum-snail-pg-dev
az postgres flexible-server stop --resource-group rg-aware-moray --name cluster-maximum-snail-pg-prod
az aks stop --resource-group rg-aware-moray --name cluster-maximum-snail
```

When you're done for good:

```bash
cd azure-k3s-cluster
terraform destroy -var="discord_webhook_url=x"
```

---

## Secret management

Sensitive runtime values are pulled from HashiCorp Vault (HCP) via the External Secrets operator — no passwords or tokens are committed to this repository. The secrets flow is:

```
HCP Vault ──▶ External Secrets operator ──▶ Kubernetes Secrets ──▶ Pods
```

To import secrets into Vault for a fresh setup, copy the example file and fill it in:

```bash
cp azure-k3s-cluster/scripts/hcp-vault-secrets.example.json \
   azure-k3s-cluster/scripts/hcp-vault-secrets.json
```

Then set `VAULT_ADDR` and `VAULT_TOKEN` and run the import script.

---

## Starting back up after a stop

After `az aks start`, the cluster comes back up with all pods re-scheduled automatically through ArgoCD. The only thing that doesn't persist through stop/start is the ArgoCD CLI session:

```bash
az aks get-credentials --resource-group rg-aware-moray --name cluster-maximum-snail --overwrite-existing
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --insecure --username admin \
  --password "$(kubectl get secret argocd-initial-admin-secret -n argocd \
    -o jsonpath='{.data.password}' | base64 -d)"
```

Kubernetes secrets persist through stop/start cycles, so you don't need to recreate them.
