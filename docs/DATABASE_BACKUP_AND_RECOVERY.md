# Serveo Database Backup & Recovery Plan

## 1. Current MongoDB Atlas Cluster Inspection & Limitations

### Inspected Environment:
- **Cluster Host**: `serveo.dip1k2e.mongodb.net`
- **Current Database**: `serveo`
- **Cluster Tier**: MongoDB Atlas Shared Cluster (`M0 Free / M2 / M5` tier).

### Capability Assessment:
| Capability | Current M0 / Shared Status | Production Requirement |
| :--- | :--- | :--- |
| **Continuous Cloud Backups** | ❌ Not available on M0/M2/M5 | Requires Atlas dedicated cluster (M10+) |
| **Point-in-Time Recovery (PITR)** | ❌ Not supported | Requires Atlas dedicated cluster (M10+) |
| **Automated UI Snapshot Restore** | ❌ Not supported | Available on M10+ |
| **Client-Side Logical Dump (`mongodump`)** | ✅ Supported via TLS connection | Supported via cron / scheduled workers |
| **Logical Collection Exports** | ✅ Supported via `backup_utility.js` | Supported |

> [!WARNING]
> Because the current cluster is an **Atlas M0/Shared cluster**, automated continuous snapshots and point-in-time recovery cannot be enabled via Atlas UI without upgrading the cluster to **M10 or higher**. Production commercial operations must either upgrade the Atlas cluster to M10 or establish the automated logical backup pipeline detailed below.

---

## 2. Operational Targets (SLAs)

Operational recovery objectives are defined as targets based on architecture:

* **Recovery Point Objective (RPO)**:
  * *With Current Setup (Scheduled Logical mongodump)*: **1 hour** (maximum 1 hour of unbacked transaction data).
  * *With Atlas M10+ Upgrade (Continuous Oplog PITR)*: **1 minute**.
* **Recovery Time Objective (RTO)**:
  * *Target*: **30 minutes** to provision or restore database state into a recovery cluster and re-point backend environment variables (`MONGO_URI`).

---

## 3. Recommended Backup Schedule & Retention Policy

For live commercial operations, establish a 3-tier retention strategy:

1. **Hourly Incremental / Logical Snapshots**:
   * Executed every hour during active restaurant operating hours (08:00 to 23:00 IST).
   * Retained for **7 calendar days**.
2. **Daily Comprehensive Snapshots**:
   * Captured at 02:00 IST daily (post closing).
   * Retained for **30 calendar days**.
3. **Monthly Archival Snapshots**:
   * Captured on the 1st of every month.
   * Retained for **1 year** in cold/glacier storage for financial compliance and accounting audit.

---

## 4. Logical Backup Script & Procedure

### Automated Backup Command (`mongodump`):
```bash
# Secure execution using environment variables (never hardcoded in shell history)
mongodump \
  --uri="${MONGO_URI}" \
  --gzip \
  --archive="./backups/serveo_backup_$(date +%Y%m%d_%H%M%S).gz"

# Encrypt archive with AES-256 before offsite upload
gpg --symmetric --cipher-algo AES256 ./backups/serveo_backup_*.gz

# Ship to immutable cloud bucket (AWS S3 / GCP Cloud Storage with Object Lock enabled)
aws s3 cp ./backups/serveo_backup_*.gz.gpg s3://serveo-production-backups/daily/
```

### Encryption & Credential Protection:
* MongoDB URI credentials must reside strictly in encrypted secret managers (Render Secret Manager / AWS Secrets Manager).
* Backup archives must be encrypted with AES-256 prior to transport and stored in buckets with MFA Delete and strict least-privilege IAM policies.

---

## 5. Restoration & Verification Procedure

> [!CAUTION]
> **Never** execute destructive restore commands (`--drop`) against a live production database. Always verify restoration in a separate isolated staging database first.

### Step-by-Step Recovery Procedure:
1. **Provision or isolate Target Cluster**:
   Create a temporary restoration database (e.g., `serveo_recovery_test`).
2. **Decrypt Archive**:
   ```bash
   gpg --decrypt serveo_backup_TIMESTAMP.gz.gpg > serveo_backup_restore.gz
   ```
3. **Execute Non-Destructive Restore**:
   ```bash
   mongorestore \
     --uri="mongodb+srv://.../serveo_recovery_test" \
     --gzip \
     --archive="serveo_backup_restore.gz" \
     --noIndexRestore # Optional: verify data before index rebuild
   ```
4. **Run Verification & Integrity Audit**:
   Execute `verifyDatabaseReadiness()` from `Backend/src/utils/backup_utility.js` against the target database:
   * Verify document count across `users`, `restaurants`, `items`, `orders`, `notifications`, `feedbacks`, and `auditlogs`.
   * Verify total revenue and order status consistency across recovered records.
5. **Switch Traffic**:
   If recovering from complete outage, update the production `MONGO_URI` environment variable on Render and trigger a zero-downtime service restart.

---

## 6. Migration Rollback Playbook

When applying schema migrations (such as adding new fields or indexes):
1. **Pre-Migration**: Generate an on-demand snapshot archive before running the migration script.
2. **Rollback Action**:
   * If a migration fails or corrupts references, revert application deployment to the previous Git commit.
   * If records require un-setting new fields:
     ```javascript
     // Safe non-destructive field removal
     db.orders.updateMany({}, { $unset: { idempotencyKey: "" } });
     ```

