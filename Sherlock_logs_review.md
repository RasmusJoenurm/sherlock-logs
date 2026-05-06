# Sherlock Logs Requirements

## Mandatory

1. Student can explain the difference between push-based and pull-based monitoring systems and justify why Prometheus uses a pull-based model.

> **Answer:** In a push-based system, instrumented services send metrics to the collector on their own schedule. In a pull-based system, the collector scrapes targets on a fixed interval. Prometheus pulls because: (1) an unreachable target is itself a signal the target is down — with push you can't tell the difference between a healthy silent target and a dead one; (2) scrape targets are declared centrally rather than each application needing to know the collector address; (3) you can debug any target by simply `curl`-ing its metrics endpoint directly.

---

2. Student can describe the architecture of the ELK stack and explain the role of each component (Elasticsearch, Logstash, Kibana).

> **Answer:** **Filebeat** (DaemonSet per node) tails container log files and ships them over the Beats protocol to **Logstash**, which filters, enriches, and tags messages before forwarding to **Elasticsearch** for indexed storage. **Kibana** connects to Elasticsearch and provides search and dashboards. In this project: Filebeat → Logstash (port 5044, `pipeline.yaml`) → Elasticsearch (`logstash-YYYY.MM.dd` indices) → Kibana.

---

3. Student can explain the advantages and disadvantages of using Prometheus over other monitoring tools like Nagios or Zabbix.

> **Answer:** Prometheus is built around a time-series data model with a powerful query language (PromQL), making it suited for dynamic cloud-native environments where services come and go. Nagios and Zabbix are check-based — they answer "is this up?" well but aren't designed for high-cardinality metric data or Kubernetes service discovery. Prometheus's downside: it requires targets to be network-reachable (pull model), and long-term storage needs extra tooling like Thanos.

---

4. Prometheus scrapes metrics at appropriate intervals. Student can explain how to adjust the scrape interval.

> **Answer:** The global scrape interval defaults to **15s** via the kube-prometheus-stack Helm chart. The backend ServiceMonitor sets `interval: 15s` explicitly (`azure-k3s-cluster/manifests/monitoring-addons/backend-servicemonitor.yaml`, line 19). The ES exporter uses `interval: 30s` (`elasticsearch-exporter.yaml`, line 25). To adjust globally, add `prometheus.prometheusSpec.scrapeInterval: "30s"` to the Helm values. Per-target overrides use the `interval:` field on each ServiceMonitor endpoint.

---

5. Node Exporter and cAdvisor (or other similar tools) are configured correctly. Student can describe common issues that might arise during their setup, such as firewall rules or incorrect endpoint configurations.

> **Answer:** Both are included automatically in kube-prometheus-stack v77.12.0 (`kube-prometheus-stack.yaml`, line 9). Node Exporter runs as a DaemonSet exposing `node_*` metrics; cAdvisor is embedded in the kubelet and scraped via `/metrics/cadvisor`. Common issues: firewall rules blocking port 9100 from Prometheus's pod CIDR to the node's host IP; Node Exporter missing `/proc`/`/sys` host path mounts (returns zero metrics); cAdvisor endpoint path varying by Kubernetes version.

---

6. Student can explain the benefits of using Grafana for visualization compared to other tools like Kibana or Datadog.

> **Answer:** Grafana speaks native PromQL so you get full label-based filtering and aggregation directly in the panel editor. Kibana is excellent for log search but less ergonomic for time-series metrics. Datadog is fully managed (zero infra overhead) but costs scale per host and create vendor lock-in. Grafana also supports multiple datasources in one dashboard — this project mixes Prometheus panels with Loki log panels side by side.

---

7. Application metrics are exposed in a Prometheus-compatible format. Student can explain how to use Prometheus client libraries to achieve this.

> **Answer:** The Go backend registers metrics using `promauto.NewCounter` / `promauto.NewHistogramVec` from `github.com/prometheus/client_golang` (`backend/packages/metrics/metrics.go`, lines 14–40). The `/api/prom_metrics` endpoint serves them via `promhttp.Handler()` (`backend/packages/api/router.go`, lines 43–45). `promauto` auto-registers with the default registry; `promhttp.Handler()` serializes everything to the standard Prometheus text format on each scrape.

---

8. Application sends at least one custom metric to Prometheus.

> **Answer:** `active_user_registrations_total` is defined as a counter in `backend/packages/metrics/metrics.go`, lines 33–40, and incremented at `backend/packages/api/userController.go`, line 49 (`metrics.ActiveUserRegistrationsTotal.Inc()`) on every successful user registration.

---

9. Application sends logs to Logstash. Student can describe how to handle log format inconsistencies and parsing errors.

> **Answer:** Filebeat (DaemonSet) tails `/var/log/containers/*.log` and forwards to Logstash on port 5044 — no application changes needed. Logstash input config: `pipeline.yaml` lines 8–11. Output to Elasticsearch: `pipeline.yaml` lines 23–30. For format inconsistencies: apply a `json` filter to attempt structured parsing, set `tag_on_failure => ["_jsonparsefailure"]` so malformed events are tagged but not dropped. A `grok` filter can extract named fields from unstructured text before matching.

---

10. Grafana dashboards are created with appropriate data sources. Student can explain how to use Grafana's query editor to filter and aggregate data.
    - VM Performance Dashboard
    - Docker Container Dashboard
    - Application Performance Dashboard

> **Answer:** All three dashboards are provisioned as ConfigMaps with label `grafana_dashboard: "1"` — Grafana's sidecar loads them automatically. Files: `grafana-dashboard-vm.yaml` (VM Performance, `node_*` metrics), `grafana-dashboard-docker.yaml` (Docker Container, `container_*` metrics), `grafana-dashboard-configmap.yaml` (Application Performance, `http_requests_total`, `http_request_duration_seconds`, `active_user_registrations_total`). In Grafana's query editor, label matchers filter data (`{job=~".*backend.*"}`) and `by (pod, namespace)` aggregations pivot across dimensions.

---

11. Kibana dashboards are created with effective visualizations. Student can describe how to use Kibana's search and filtering capabilities to analyze logs.
    - System Logs Dashboard
    - Application Logs Dashboard
    - Docker Logs Dashboard

> **Answer:** All three dashboards are defined as NDJSON in `azure-k3s-cluster/manifests/monitoring-addons/kibana-dashboards-configmap.yaml` (system: line 9, application: line 17, docker: line 25) and imported by the `kibana-dashboard-import` Job (`kibana-dashboard-import-job.yaml`, lines 67–69) which runs as an ArgoCD PostSync hook. In Kibana, KQL filters narrow logs by field (`kubernetes.container.name: backend AND message: ERROR`); the Discover view supports full-text search across all indexed fields; saved searches can be embedded directly into dashboard panels.

---

12. System provides real-time performance metrics across the infrastructure. Student can explain how to troubleshoot common issues with metric collection.

> **Answer:** Prometheus scrapes every 15s; Grafana auto-refreshes every 30s — data is at most 30 seconds old. To troubleshoot: check `Status → Targets` in Prometheus UI for scrape errors; manually curl a target's metrics endpoint from inside the cluster to confirm it's reachable; compare ServiceMonitor label selectors against Service labels if a target isn't discovered (`kubectl get servicemonitor -o yaml` vs `kubectl get svc --show-labels`).

---

13. Historical performance data is available through the implemented tools. Student can explain how to create long-term retention policies for metrics and logs.

> **Answer:** Prometheus retains 15 days by default (configurable via `prometheusSpec.retention`). Elasticsearch stores logs in daily rolling indices indefinitely until disk is exhausted. For long-term retention: Prometheus → use Thanos or Cortex to ship blocks to object storage; Elasticsearch → configure an ILM policy with a `delete` phase (e.g. `"min_age": "30d"`). This project also provisions an Azure Blob Storage container via Terraform for log archival (`enable_logs_storage=true`).

---

14. Setup of the new monitoring and logging VM is incorporated into the existing automation flow.

> **Answer:** All monitoring components are ArgoCD Applications declared in `azure-k3s-cluster/manifests/argocd/apps/`. The root application (`root-application.yaml`) watches that directory with `selfHeal: true` and auto-syncs — any change pushed to git is reconciled to the cluster without manual intervention. Monitoring is not a separate step; it's part of the same GitOps tree as the application.

---

15. CI/CD pipeline deploys monitoring and logging agents. Student can describe how to handle agent configuration dynamically based on the environment.

> **Answer:** `.github/workflows/gitops-cicd.yaml` (lines 78–83) syncs `gitops-galaxy-root` on every push, which includes the monitoring-addons Application containing the Filebeat DaemonSet. For dynamic per-environment config: Filebeat uses Kubernetes autodiscover — it reads pod metadata and captures logs from all namespaces automatically without per-environment config. For different processing rules per environment, Filebeat `condition` blocks can apply different processors based on pod labels or namespace names.

---

16. Grafana alerts are configured with appropriate thresholds. Student can explain how to avoid alert fatigue by setting sensible alert conditions.

> **Answer:** All 11 alert rules are in `kube-prometheus-stack.yaml` under `additionalPrometheusRulesMap` (lines 31–137). Alertmanager routes to Discord via `alertmanager-discord-config` secret (`scripts/create-alertmanager-secret.sh`). Alert fatigue is reduced by: `for: 5m` duration on CPU/memory rules to ignore transient spikes; `group_wait: 30s` and `group_interval: 5m` to batch simultaneous alerts; `repeat_interval: 2h` so sustained alerts don't re-notify constantly; inhibit rules that silence warnings when a critical alert for the same resource is already active.

---

17. Logstash sends alert notifications based on log patterns. Student can explain how to use Logstash filters to parse and match log entries.

> **Answer:** Filter in `pipeline.yaml` lines 13–20: if `[message]` matches `/ERROR|Exception|CRITICAL|Failed password|authentication failed| 500 | 502 | 503 | 504 /`, the event gets tagged `"alert"`. Output block (lines 32–42) sends tagged events to Discord via HTTP. To match against parsed fields instead of raw message, apply a `json` or `grok` filter first, then use `if [level] == "ERROR"` on the extracted field.

---

18. Student can explain how to fine-tune alert thresholds and conditions to reduce false positives.

> **Answer:** Use `for:` duration to require a condition to be continuously true (a 30-second CPU spike with `for: 5m` never fires). Use `rate()` instead of raw counters — it normalizes across varying scrape intervals. Exclude known-noisy sources with label matchers (`{fstype!~"tmpfs|overlay"}`). Use `histogram_quantile` for latency instead of averages — an average can look healthy while tail latency is terrible. Test thresholds against real traffic patterns before shipping, and tune `group_wait`/`repeat_interval` in Alertmanager to reduce notification volume from persistent alerts.

---

19. Alerts trigger when CPU usage exceeds 80% for more than 5 minutes.
    > Test: Run `stress-ng --cpu 8 --timeout 360s` or similar to simulate high CPU usage. Adjust time as necessary.

> **Answer:** Rule `NodeCPUHighUsage` in `kube-prometheus-stack.yaml`, lines 36–44:
> ```
> (1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100 > 80
> for: 5m, severity: critical
> ```
> Measures idle CPU fraction per node, subtracts from 1, converts to percentage.

---

20. Alerts trigger when available disk space falls below 20%.
    > Test: Run `fallocate -l 10G large_file.img` or similar to simulate low disk space.

> **Answer:** Rule `NodeDiskLow` in `kube-prometheus-stack.yaml`, lines 45–53:
> ```
> (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) * 100 < 20
> for: 5m, severity: critical
> ```
> The `fstype` exclusion filters out tmpfs and overlay mounts so only real persistent filesystems are evaluated.

---

21. Alerts trigger when memory usage exceeds 90% for more than 5 minutes.
    > Test: Run `stress-ng --vm 2 --vm-bytes 80% --timeout 360s` or similar to simulate high memory usage. Adjust time as necessary.

> **Answer:** Rule `NodeMemoryHighUsage` in `kube-prometheus-stack.yaml`, lines 54–62:
> ```
> (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
> for: 5m, severity: critical
> ```
> Uses `MemAvailable` (not `MemFree`) because available accounts for reclaimable page cache, giving an accurate picture of what's actually usable.

---

22. Alerts trigger when a container restarts more than 3 times in 15 minutes.
    > Test: Run `docker run --restart=always --name test_container ubuntu /bin/bash -c "sleep 10; exit 1"` or similar to simulate container restarts.

> **Answer:** Rule `ContainerRestartingFrequently` in `kube-prometheus-stack.yaml`, lines 63–71:
> ```
> increase(kube_pod_container_status_restarts_total[15m]) > 3
> for: 1m, severity: warning
> ```
> `kube_pod_container_status_restarts_total` is exported by kube-state-metrics, part of the chart.

---

23. Alerts trigger when container memory usage exceeds 80% of its limit.
    > Test: Run `docker run -m 512m --name memory_test ubuntu /bin/bash -c "stress-ng --vm 1 --vm-bytes 450M --timeout 360s"` or similar to simulate high container memory usage.

> **Answer:** Rule `ContainerMemoryLimitHigh` in `kube-prometheus-stack.yaml`, lines 72–80:
> ```
> (container_memory_working_set_bytes{container!="", pod!=""} / kube_pod_container_resource_limits{resource="memory", unit="byte"}) * 100 > 80
> for: 5m, severity: warning
> ```
> Uses `working_set_bytes` — the same metric the kubelet uses for OOM decisions.

---

24. Alerts trigger when any VM becomes unreachable.
    > Test: Run `sudo ifconfig eth0 down` or similar to simulate a VM becoming unreachable.

> **Answer:** Rule `InstanceDown` in `kube-prometheus-stack.yaml`, lines 81–88:
> ```
> up == 0
> for: 1m, severity: critical
> ```
> `up` is a synthetic metric Prometheus sets to 0 when a scrape fails. It exists for every target, so any unreachable node-exporter triggers this within one scrape cycle.

---

25. Alerts trigger when Elasticsearch cluster status changes to yellow or red.
    > Test: Stop one of the Elasticsearch nodes in a multi-node cluster to simulate a yellow state.

> **Answer:** Rule `ElasticsearchClusterNotHealthy` in `kube-prometheus-stack.yaml`, lines 89–97:
> ```
> elasticsearch_cluster_health_status{color=~"yellow|red"} == 1
> for: 5m, severity: critical
> ```
> Metric is exported by the `prometheus-elasticsearch-exporter` (`elasticsearch-exporter.yaml`), which polls the ES cluster health API.

---

26. The README file contains a clear project overview, setup instructions, and usage guide.

> **Answer:** `README.md` contains: ASCII architecture diagram, prerequisites with installation links, step-by-step setup (Terraform → ArgoCD → secrets → app sync → CI/CD), port-forward access instructions for Grafana/Prometheus/Kibana, dashboard and alert reference tables, and stop/teardown commands.

---

27. The code is well-organized, properly commented, and follows best practices for the chosen programming language(s).

> **Answer:** Backend Go code separates concerns across packages: `metrics/` for all Prometheus declarations, `api/` for handlers and routing, `db/` for the data layer, `config/` for environment-based configuration. No secrets hardcoded anywhere. Infrastructure follows the same principle — one ArgoCD Application file per component, one Terraform file per concern. Non-obvious decisions are commented (e.g. why Kibana has no auto-sync, why ES replicas default to 0).

---

## Extra

28. Advanced alerting rules trigger based on trends or combinations of metrics. Student can describe how to use Prometheus' PromQL to create complex alert conditions.

> **Answer:** Four advanced rules in `kube-prometheus-stack.yaml` lines 98–137:
> - `BackendHighLatencyP95`: `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m]))) > 1` — sustained p95 latency over 1s for 5 min
> - `BackendErrorRateHigh`: `sum(rate(http_requests_total{status_code=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100 > 5` — 5xx error ratio over 5%
> - `PodMemoryPressureAndRestarts`: joins memory > 85% of limit `and on(namespace, pod, container)` restart count > 2 in 10 min — combination alert requiring both conditions simultaneously
> - `SustainedPodCPUHigh`: pod CPU > 0.8 cores for 10 continuous minutes — trend-based, long `for:` filters out transient spikes

---

29. Monitoring system sends notifications to an external platform. Student can explain how to handle notification throttling and escalation policies.

> **Answer:** Two independent Discord notification paths: (1) Prometheus Alertmanager → Discord via `alertmanager-discord-config` secret (`scripts/create-alertmanager-secret.sh`) — routes `critical` and `warning` to separate receivers; (2) Logstash → Discord directly on log pattern match (`pipeline.yaml` lines 32–42). Throttling: Alertmanager `group_wait: 30s`, `group_interval: 5m`, `repeat_interval: 2h` batch and deduplicate. Escalation: additional routes in the Alertmanager config can send criticals to a second receiver (e.g. PagerDuty) while warnings go only to Discord.

---

30. Student has implemented additional technologies, security enhancements and/or features beyond the core requirements.

> **Answer:**
> - **ArgoCD GitOps** with `selfHeal: true` — full declarative cluster management, every drift auto-corrected
> - **Loki + Promtail** — second logging stack alongside ELK, queryable from Grafana with LogQL
> - **Multi-environment CI/CD** — dev auto-deploys on push, prod requires GitHub environment approval; both have ArgoCD rollback on failure (`.github/workflows/gitops-cicd.yaml` lines 85–87, 133–135)
> - **External Secrets + HCP Vault** — application secrets sourced from Vault, never stored as static K8s secrets
> - **Azure managed PostgreSQL with HA and PITR** — production database with automated backups and point-in-time restore
> - **Azure P2S VPN + private DNS** (`network-vpn.tf`, `dns.tf`) — private access to dev and tooling; only production is publicly exposed
> - **Terraform remote state** on Azure Blob Storage — shared, lockable state for safe multi-session usage
