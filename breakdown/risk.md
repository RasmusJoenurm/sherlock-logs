# Risk Assessment and Management Plan

## 1. Purpose

This plan defines how migration risk and cloud cost risk are controlled for the target `test` and `prod` environments.

## 2. Key Risk Areas

### 2.1 Cost management risks

- Unbounded autoscaling in peak periods
- NAT/LB/data-transfer underestimation
- Log and backup storage accumulation
- Idle resources left running (test, runners, unattached disks)

### 2.2 Operational risks

- Resource contention without isolated node pools
- Monitoring blind spots during migration
- CI/CD bottlenecks during high deployment frequency
- Cross-environment blast radius from insufficient isolation

### 2.3 Security and compliance risks

- Excessive IAM permissions
- Secrets sprawl in CI/CD and app configs
- Missing encryption/tls controls
- Incomplete access audit trail

### 2.4 Security Challenges: On-Premises vs Cloud

On-premises: single firewall + network segmentation
Cloud requires:

- Explicit IAM roles per service + IRSA for Kubernetes
- Network policies (K8s NetworkPolicy) + security groups (per subnet)
- Data encryption in transit (TLS) + at rest (managed keys)
- Audit logging mandatory (CloudTrail, Azure Activity Log) vs optional on-prem

## 3. Cost Management Controls

- Budgets and alerts:
    - Scope: per environment (`test`, `prod`, `shared`) and total
    - Thresholds: 50%, 80%, 100%, and forecasted-overrun alert
- Weekly cost review:
    - top 10 services by spend
    - delta vs prior week
    - anomalies and owner assignment
- Monthly optimization sprint:
    - right-sizing
    - retention tuning
    - orphan cleanup

## 4. Resource Optimization Strategy

### 4.1 Compute

- Separate node pools:
    - `main`, `monitoring`, `tools`
- Use autoscaling with sane min/max bounds per environment.
- Prefer spot/preemptible for non-critical test workloads.

### 4.2 Storage and data lifecycle

- Logs:
    - hot retention for operational triage
    - lifecycle to cool/archive for annual retention target
- Backups:
    - prod: 30 daily backups + PITR
    - test: reduced retention
- Automated cleanup:
    - unused volumes
    - old snapshots
    - stale images and artifacts

### 4.3 Network cost optimization

- Minimize cross-zone chatter for chatty components.
- Keep private traffic local to VPC/VNet zones where possible.
- Evaluate NAT architecture monthly versus traffic profile.

## 5. Risk Mitigation Approach

### 5.1 Pre-migration

- Define SLOs and rollback criteria for each service.
- Freeze non-essential changes during cutover windows.
- Validate observability parity before traffic shift.

### 5.2 Migration execution

- Use phased rollout:
    - test validation
    - partial production canary
    - full cutover
- Keep rollback path ready:
    - immutable image tags
    - versioned Helm values
    - DB backup/restore validation

### 5.3 Post-migration

- Hypercare period (2-4 weeks):
    - daily cost and reliability review
    - incident trend tracking
    - rightsizing and policy tuning

## 6. Tagging and Ownership Strategy

Mandatory tags/labels on all resources:

- `env`: `test` | `prod` | `shared`
- `service`: app/monitoring/db/cicd/network
- `owner`: team or person
- `cost-center`: finance mapping key
- `criticality`: low/medium/high
- `lifecycle`: ephemeral/long-lived

Governance rules:

- No deployment without required tags.
- Budget policies tied to tags.
- Monthly orphan resource report.

## 7. IAM and Access Controls

- Least privilege role design by workload and environment.
- Separate accounts/subscriptions/projects:
    - `test`
    - `prod`
    - `shared`
- Service identities for workloads (no static credentials in code/manifests).
- Enforce MFA and short session durations for privileged human access.

## 8. Monitoring and Alerting Controls

Required stack and retention:

- Metrics: 30 days
- Logs: 365 days
- Alerts:
    - availability, latency, error rate, saturation
    - cost anomaly alerts
    - security event alerts

Recommended minimum operational alerts:

- High p95 backend latency
- Error-rate spikes frontend/backend
- DB CPU/IOPS saturation
- Node disk pressure
- Pod restarts and OOM increases
- Budget threshold breaches
### 8.1 Disaster Recovery SLOs
- RTO: 4 hours (full cluster rebuild from backups)
- RPO: 1 hour (hourly snapshots for prod DB, PITR for point recovery)
## 9. Residual Risks and Acceptance

Residual risks that remain after controls:

- Sudden traffic spikes causing short-term cost bursts
- Provider pricing changes over time
- Unexpected dependency behavior under production latency

Acceptance approach:

- Keep 10-15% monthly budget contingency
- Re-baseline capacity and pricing quarterly
- Run regular disaster recovery and restore tests