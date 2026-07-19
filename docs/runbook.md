# Runbook

Ops playbook for the observability platform. Each alert defined in [`alerts/`](../alerts/) links back to a section here.

## Table of contents

- [Alerts](#alerts)
  - [mimir-ingester-oom](#mimir-ingester-oom)
  - [mimir-ingester-memory](#mimir-ingester-memory)
  - [mimir-compactor-lag](#mimir-compactor-lag)
  - [object-storage-writes](#object-storage-writes)
  - [tenant-quota](#tenant-quota)
  - [high-error-rate](#high-error-rate)
  - [high-latency](#high-latency)
- [Operations](#operations)
  - [Upgrade a component](#upgrade-a-component)
  - [Backup and restore](#backup-and-restore)
  - [Rotate object storage credentials](#rotate-object-storage-credentials)
  - [Recover from full disks](#recover-from-full-disks)
  - [Investigate slow queries](#investigate-slow-queries)

---

## Alerts

### mimir-ingester-oom

**Symptom**: `MimirIngesterOOMKilled` firing. One or more Mimir ingester pods have been OOMKilled recently.

**Impact**: Any samples buffered in that ingester's memory since the last WAL checkpoint may be lost (up to 15 minutes of one replica's writes, mitigated by RF=3).

**Diagnose**:

```bash
kubectl -n observability get pods -l app.kubernetes.io/component=ingester
kubectl -n observability describe pod <ingester-pod>
kubectl -n observability logs <ingester-pod> --previous | tail -100
```

**Common causes and fixes**:

1. **Traffic spike from a single tenant** — check `Ingest samples/s per tenant` panel on the meta dashboard. Apply a temporary tighter limit in that tenant's `limits.yaml`, or raise the ingester memory limit.
2. **Cardinality explosion** — check `max_global_series_per_user` limit in Mimir logs. Ask the tenant to reduce label cardinality (usually a `user_id` or `trace_id` promoted to a label by mistake).
3. **Under-provisioned** — legitimate growth. Bump `ingester.resources.limits.memory` in `kubernetes/platform/mimir/values-live.yaml` and roll out.

**Recovery**: OOMKilled ingester restarts automatically. Verify write path is healthy:

```bash
kubectl -n observability get pods -l app.kubernetes.io/component=ingester -w
```

Expected: all replicas `Running`, `READY 1/1`.

---

### mimir-ingester-memory

**Symptom**: `MimirIngesterHighMemoryUse` — ingester sustained > 85% memory for 15m.

**Diagnose**: same as above. This is the early-warning version of the OOM alert.

**Action**: if this fires, treat it as a 30-minute deadline to act before ingesters start OOMing.

---

### mimir-compactor-lag

**Symptom**: `CompactorLagging` — Mimir compactor hasn't completed a run in > 1h.

**Impact**: object storage grows unnecessarily; query performance for older data degrades over time.

**Diagnose**:

```bash
kubectl -n observability logs deploy/mimir-compactor | tail -100
```

Look for permission errors, retries against object storage, or long individual compaction jobs.

**Common causes**:

1. **Object storage credentials expired** — check for 403 responses. Rotate credentials.
2. **Compactor under-provisioned for tenant count** — scale replicas or bump CPU.
3. **Stuck compaction job** — restart the compactor pod: `kubectl -n observability rollout restart deploy/mimir-compactor`.

---

### object-storage-writes

**Symptom**: `ObjectStorageWriteFailures` — > 5% write error rate on the object store.

**Impact**: **critical**. New data may not be durable. Ingesters buffer in memory but only briefly.

**Diagnose**:

```bash
# Check credentials mounted correctly
kubectl -n observability exec deploy/mimir-ingester -- env | grep S3
# Direct probe (if you have a debug pod)
kubectl -n observability run s3-probe --rm -it --image=amazon/aws-cli -- s3 ls s3://$BUCKET
```

**Common causes and fixes**:

1. **Credentials rotated** — update the `Secret` sourced by external-secrets, or set new keys and force a `kubectl rollout restart`.
2. **Bucket policy changed** — the platform's IAM identity needs `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`, `s3:ListBucket`.
3. **Provider outage** — check status page. There's nothing to fix in the cluster; wait it out. Ingesters keep buffering.

---

### tenant-quota

**Symptom**: `TenantMetricsIngestRateNearLimit` or `TenantSeriesNearLimit` — a tenant approaching its configured cap.

**Action**:

1. Confirm the tenant owner is aware.
2. Decide together: raise the limit (needs justification), or reduce cardinality on the tenant's side.
3. Update `kubernetes/tenants/<tenant>/limits.yaml`, commit, let ArgoCD sync.
4. If the tenant hits the hard cap, Mimir will reject new samples with a 429. Log lines: `sample dropped due to per-user series limit`.

---

### high-error-rate

**Symptom**: `DefaultHighErrorRate` — a service is serving > 5% 5xx responses.

**Not a platform incident**; a tenant service is unhealthy. The alert is a **default one every tenant inherits** because it is the most common signal that something is broken.

**Escalate to**: the tenant owner in the tenant's `README.md`.

Grafana → Explore → Loki with the tenant datasource and `service_name=<broken-service>`, filter by log level to see errors quickly.

---

### high-latency

**Symptom**: `DefaultHighLatencyP99` — P99 latency above 1s for 10 minutes.

**Investigate**:

1. Load `Golden Signals — RED` dashboard, look at latency trend.
2. Jump from a spike into Tempo (Grafana correlations). Identify slow spans.
3. From a slow span, jump to Pyroscope if profiling is instrumented — usually reveals the hotspot function.

---

## Operations

### Upgrade a component

Chart versions live in [`kubernetes/platform/versions.yaml`](../kubernetes/platform/versions.yaml). Bump one line per PR.

Rollout procedure:

1. Read the component's release notes.
2. Test locally: `make local-down && make local-up`. Verify no breaking changes.
3. PR the version bump.
4. Merge — ArgoCD syncs the change. Watch pods roll:

```bash
kubectl -n observability rollout status deploy/<component>
```

5. Verify Grafana still shows data from `_meta` and at least one demo tenant.

Never bump more than one component's version in the same PR. If it goes wrong, you want to know exactly what changed.

### Backup and restore

**What actually needs backing up:**

- Grafana database (dashboards, users, alerts) — small, backup nightly.
- Object storage — the source of truth for all telemetry data. Rely on the provider's versioning + lifecycle rules; don't back it up separately unless retention is < 30d.

**Grafana backup**:

```bash
kubectl -n observability exec deploy/grafana -- sqlite3 /var/lib/grafana/grafana.db ".backup /tmp/grafana.db"
kubectl -n observability cp deploy/grafana:/tmp/grafana.db ./backups/grafana-$(date +%F).db
```

Automate via a CronJob (see `kubernetes/observability-meta/grafana-backup.yaml` when added).

**Restore**:

Grafana dashboards are recreated automatically from `dashboards/` on next sync. Users/alerts require restoring the sqlite file.

### Rotate object storage credentials

1. Generate new keys in the object storage provider.
2. Update the `ExternalSecret` (or the raw `Secret` in local) with the new keys.
3. Roll each affected deployment:

```bash
for c in mimir loki tempo pyroscope; do
  kubectl -n observability rollout restart deploy -l app.kubernetes.io/name=$c
done
```

4. Revoke the old keys.

### Recover from full disks

Ingesters keep a local WAL on their PV. If the PV fills:

1. Identify: `kubectl -n observability describe pvc | grep -i "space\|used"`.
2. Free space: bump PVC size (if StorageClass allows expand) — edit the PVC, then delete the pod so it rebinds.
3. Root cause: usually the WAL isn't shipping to object storage. Check ingester logs for shipping errors.

### Investigate slow queries

Grafana → Explore → the tenant's Mimir datasource. Load the query. If slow:

1. Check `Query stats` in Grafana; note fetched series count.
2. Query too broad? Narrow the label matchers.
3. Time range too long? Prefer recording rules for frequently-run heavy queries.
4. Store gateway pod under-provisioned? Bump replicas.
