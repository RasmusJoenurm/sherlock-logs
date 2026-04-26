# Cloud Provider Comparison: Azure vs AWS
## Cloud Deployment Models

Hybrid IaaS/PaaS:
- **Kubernetes (IaaS)**: Chosen because custom resource requirements, GitOps compatibility, and multi-environment isolation
- **Managed PostgreSQL (PaaS)**: Avoids operational burden of DB patches, backups, HA failover
- Why not fully serverless (FaaS)? Stateful backend, long-lived monitoring stack, and Helm-based app deployment require container runtime

## Measured Baseline Target Metrics
To finalize cloud sizing, collect:
- Backend CPU: expect 200-300m avg @ 1000 users
- Database QPS: estimate 500-1000 TPS @ peak
- Egress: rough 1-5 Gbps @ peak traffic spikes

## 1. Comparison Scope

This document compares Azure and AWS for the target migration architecture:
- Environments: `test`, `prod`, and `shared`
- Kubernetes: managed control plane + VM node pools
- Managed PostgreSQL with HA in prod
- Monitoring and logging retention requirements
- GitOps CI/CD with GitLab + Argo CD

## 2. Target Service Mapping

| Requirement | Azure | AWS |
|---|---|---|
| Kubernetes (non-serverless mode) | AKS | EKS (EC2 node groups) |
| Node pools/groups | AKS node pools | EKS managed node groups |
| Managed PostgreSQL | Azure Database for PostgreSQL Flexible Server | Amazon RDS for PostgreSQL |
| Private container registry | Azure Container Registry (ACR) | Amazon ECR |
| Object storage for logs/backups | Azure Blob Storage | Amazon S3 |
| Public DNS | Azure DNS | Route 53 Public Hosted Zone |
| Private DNS | Azure Private DNS | Route 53 Private Hosted Zone |
| Public app load balancing | Azure Load Balancer / App Gateway Ingress | ALB/NLB (via AWS Load Balancer Controller) |
| Private/internal load balancing | Internal LB | Internal NLB/ALB |
| NAT egress | Azure NAT Gateway | AWS NAT Gateway |
| VPN access to private network | Azure VPN Gateway | AWS Client VPN |
| Identity and permissions | Azure RBAC + Managed Identity | IAM roles + IRSA |
| Billing and budgets | Azure Cost Management + Budgets | AWS Budgets + Cost Explorer |

## 3. Exact Calculator Specs (for both providers)

### 3.1 Regions
- Azure: `West Europe`
- AWS: `eu-west-1` 

### 3.2 Kubernetes clusters and node pools

### Prod cluster
- `main` pool/group:
  - min 4, max 12
  - Azure VM: `Standard_D4s_v5` (4 vCPU, 16 GiB)
  - AWS EC2: `m6i.xlarge` (4 vCPU, 16 GiB)
- `monitoring` pool/group:
  - min 2, max 6
  - Azure VM: `Standard_D8s_v5` (8 vCPU, 32 GiB)
  - AWS EC2: `m6i.2xlarge` (8 vCPU, 32 GiB)
- `tools` pool/group:
  - min 2, max 4
  - Azure VM: `Standard_D4s_v5`
  - AWS EC2: `m6i.xlarge`

### Test cluster
- `main` pool/group:
  - min 2, max 4
  - Azure VM: `Standard_D4s_v5`
  - AWS EC2: `m6i.xlarge`
- `monitoring` pool/group:
  - min 1, max 2
  - Azure VM: `Standard_D4s_v5`
  - AWS EC2: `m6i.xlarge`
- `tools` pool/group:
  - min 1, max 2
  - Azure VM: `Standard_D2s_v5` (2 vCPU, 8 GiB)
  - AWS EC2: `m6i.large` (2 vCPU, 8 GiB)

### 3.3 Database specs

### Prod
- Azure PostgreSQL Flexible Server:
  - General Purpose, 4 vCPU, 16 GiB
  - Zone-redundant HA enabled
  - 500 GiB storage
  - 30-day backups + PITR
  - 7-day logs retention
- AWS RDS PostgreSQL:
  - `db.m6g.xlarge`
  - Multi-AZ enabled
  - 500 GiB `gp3` (3000 IOPS)
  - 30-day backups + PITR
  - 7-day logs retention

### Test
- Azure PostgreSQL Flexible Server:
  - 2 vCPU, 8 GiB
  - Single-zone
  - 200 GiB storage
  - 7-day backup retention
- AWS RDS PostgreSQL:
  - `db.m6g.large`
  - Single-AZ
  - 200 GiB `gp3`
  - 7-day backup retention

### 3.4 Networking specs
- Public load balancer: 1 per environment
- Internal load balancer: 1 per environment
- NAT:
  - Azure: 1 NAT Gateway per environment (2 total)
  - AWS: 3 NAT Gateways in prod (multi-AZ) + 1 in test
- VPN:
  - Azure: 1 `VpnGw1`
  - AWS: 1 Client VPN endpoint
- DNS:
  - 1 public hosted zone
  - 1 private hosted zone

### 3.5 Storage and registry specs
- Registry:
  - Azure ACR Standard, 100 GiB images
  - AWS ECR private, 100 GiB images
- K8s PV storage:
  - prod monitoring/logging: 500 GiB
  - test monitoring/logging: 100 GiB
- Object storage for long-term logs:
  - ~18 TB/year with lifecycle to cool/archive tiers
- Internet egress planning input:
  - 2.5 TB/month total (prod + test)

### 3.6 Shared CI/CD specs
- GitLab VM:
  - 4 vCPU, 16 GiB RAM, 200 GiB SSD
- Runner VMs:
  - 2 x (2 vCPU, 8 GiB RAM)

## 4. Free Tier Analysis

| Category | Azure | AWS | Practical relevance for this target |
|---|---|---|---|
| Kubernetes | AKS control plane benefits may vary by tier/region | EKS billed per cluster-hour | Low for production-scale target |
| Compute | Limited credits/trials and promo offers | 12-month free tier for selected EC2 sizes | Low |
| Managed DB | Usually not covered at required scale | Limited free options not enough for HA prod | Low |
| Object storage | Small promotional limits | S3 free tier small | Low |
| Networking/NAT/LB | Generally billable | Generally billable | None for this architecture |

Conclusion: free tiers are not materially useful for the required HA multi-env architecture.

## 5. Pricing Model Comparison

- On-demand:
  - Best for baseline forecasting and initial migration phase
- Spot/preemptible:
  - Good for test workers and non-critical CI runners
  - Avoid for stateful prod components
- Reserved/committed:
  - Recommended for steady prod node pools and database after usage stabilizes
- Storage tiering:
  - Keep recent logs in hot tier, age out to cool/archive to control annual retention costs
### 5.1 On-Demand Baseline Rationale
On-demand pricing is forecasted because:
- Initial migration phase avoids commitment lock-in
- Autoscaling unpredictability (test vs prod demand varies weekly)
- Reserved instances recommended post-stabilization (3-6 months into production)

### 5.2 Spot/Preemptible Applicability
Test cluster workers and CI runners are candidates for 70-80% savings via spot, 
provided pod disruption budgets and rapid re-deployment are acceptable.

## 6. Supplementary and Hidden Cost Categories

- Public IP and static IP allocations
- NAT Gateway hourly + data processing charges
- Load balancer hourly + processed traffic dimensions
- Cross-AZ and internet egress charges
- Backup growth and snapshot retention costs
- API request/operation charges (storage, monitoring, logs)
- Idle resources (unused disks, idle LBs, orphaned IPs)

## 7. Official Pricing Documentation

### Azure
- AKS: `https://azure.microsoft.com/pricing/details/kubernetes-service/`
- Linux VMs: `https://azure.microsoft.com/pricing/details/virtual-machines/linux/`
- PostgreSQL Flexible Server: `https://azure.microsoft.com/pricing/details/postgresql/flexible-server/`
- NAT Gateway: `https://azure.microsoft.com/pricing/details/azure-nat-gateway/`
- Bandwidth: `https://azure.microsoft.com/pricing/details/bandwidth/`
- Azure Pricing Calculator: `https://azure.microsoft.com/pricing/calculator/`

### AWS
- EKS: `https://aws.amazon.com/eks/pricing/`
- EC2 on-demand: `https://aws.amazon.com/ec2/pricing/on-demand/`
- RDS PostgreSQL: `https://aws.amazon.com/rds/postgresql/pricing/`
- VPC/NAT Gateway: `https://aws.amazon.com/vpc/pricing/`
- Data transfer: `https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer`
- AWS Pricing Calculator: `https://calculator.aws/`