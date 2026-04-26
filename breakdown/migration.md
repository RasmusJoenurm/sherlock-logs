# Migration Cost Analysis (Azure vs AWS)

## 1. Costing Method

This analysis uses:
- Two production-like environments: `test` and `prod`
- Separate shared services scope (`GitLab`, registry, DNS/VPN primitives)
- On-demand pricing baseline
- 730 hours/month
- Region pair:
  - Azure `West Europe`
  - AWS `eu-west-1`

Values below are planning estimates and should be finalized with calculator exports using identical specs from `cloud-provider-comparison.md`.

### 1.1 CapEx vs OpEx Translation
Current on-premises infrastructure (data center lease, server hardware, maintenance staff):
- Annual cost (estimated): $X (provide your guess)
- Converted to cloud OpEx: \$3.1k × 12 = $37.2k/year
- Benefit: No capital outlay, flexible scaling, vendor-managed updates
## 2. Exact Bill of Materials 

### 2.1 Kubernetes
- 2 clusters (`test`, `prod`)
- Node pools/groups and sizes exactly as defined in comparison document:
  - Prod: main/monitoring/tools
  - Test: main/monitoring/tools
- Autoscaling enabled

### 2.2 Database
- Prod managed PostgreSQL HA:
  - Azure Flexible Server 4 vCPU/16 GiB, 500 GiB, HA, 30-day backup
  - AWS RDS PostgreSQL db.m6g.xlarge Multi-AZ, 500 GiB gp3, 3000 IOPS, 30-day backup
- Test managed PostgreSQL non-HA:
  - Azure 2 vCPU/8 GiB, 200 GiB
  - AWS db.m6g.large, 200 GiB gp3

### 2.3 Network and edge
- Per environment:
  - 1 public LB
  - 1 internal LB
- NAT:
  - Azure: 2 total
  - AWS: 4 total (3 prod + 1 test)
- VPN: 1 endpoint
- DNS: 1 public + 1 private zone
- Internet egress: 2.5 TB/month total

### 2.4 Storage/observability
- Registry storage: 100 GiB
- K8s PVs:
  - prod 500 GiB
  - test 100 GiB
- Logs archive: 18 TB/year
- Metrics retention: 30 days
- Log retention: 365 days

### 2.5 Shared CI/CD
- GitLab VM: 4 vCPU, 16 GiB, 200 GiB
- 2 runner VMs: each 2 vCPU, 8 GiB

## 3. Monthly Cost Estimate (Baseline)

| Major component | Azure (USD/mo) | AWS (USD/mo) |
|---|---:|---:|
| K8s worker compute (all pools) | 1,750 | 1,820 |
| K8s control plane | 0-150 | 146 |
| Managed PostgreSQL (prod+test) | 480 | 520 |
| Networking (LB + NAT + VPN + DNS) | 360 | 520 |
| Storage (PV + backups + object + registry) | 210 | 230 |
| Shared CI/CD compute | 210 | 220 |
| Data transfer + request overhead | 260 | 300 |
| **Estimated monthly total** | **~3,120** | **~3,756** |
### 3.1 Cost Sensitivity Analysis
If traffic grows 2x:
- Compute (autoscaling): +$400–600
- Data egress: +$150–200
- Storage (logs): +$50–80
- Revised estimate: ~\$3.7k–4.0k/month

## 4. Hidden Cost Considerations

- NAT gateway data processing can materially increase costs at scale.
- Multi-AZ traffic patterns increase east-west transfer charges.
- Log growth and backup retention can outpace compute spend over time.
- Load balancer costs include fixed and usage dimensions.
- Idle persistent volumes, orphaned snapshots, and unused public IPs are common leak sources.

## 5. Optimization Scenarios

### 5.1 Cost-optimized test environment
- Use spot/preemptible nodes for test workloads where disruption is acceptable.
- Shut down non-critical test runners and tools outside office hours.
- Reduce test log retention and archive aggressively.

Expected reduction for test scope: 25-45% depending on uptime and spot utilization.

### 5.2 Steady-state production optimization
- Commit/reserve baseline node capacity and DB once usage stabilizes.
- Keep burst portion on on-demand autoscaling.
- Apply storage lifecycle policy:
  - hot (7-14 days) -> cool -> archive

Expected reduction for stable prod baseline: 15-30% over pure on-demand.

## 6. Cost Management Controls

- Budget alerts at 50%, 80%, 100% per env and per cost center.
- Mandatory tags/labels:
  - `env`, `owner`, `service`, `cost-center`, `criticality`, `lifecycle`
- Weekly anomaly detection review and monthly right-sizing review.

## 7. Final Comparison Summary

- Azure estimate: **~\$3.1k/month baseline** (recommended budget guardrail: **$3.6k**)
- AWS estimate: **~\$3.8k/month baseline** (recommended budget guardrail: **$4.3k**)

Under the specified architecture and assumptions, Azure is forecasted lower mainly due to the selected network/NAT topology and comparable compute/database sizing.

## 8. Pricing References

- Azure pricing pages:
  - `https://azure.microsoft.com/pricing/details/kubernetes-service/`
  - `https://azure.microsoft.com/pricing/details/virtual-machines/linux/`
  - `https://azure.microsoft.com/pricing/details/postgresql/flexible-server/`
  - `https://azure.microsoft.com/pricing/details/azure-nat-gateway/`
  - `https://azure.microsoft.com/pricing/details/bandwidth/`
- AWS pricing pages:
  - `https://aws.amazon.com/eks/pricing/`
  - `https://aws.amazon.com/ec2/pricing/on-demand/`
  - `https://aws.amazon.com/rds/postgresql/pricing/`
  - `https://aws.amazon.com/vpc/pricing/`
  - `https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer`