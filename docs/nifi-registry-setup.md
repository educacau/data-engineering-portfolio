# NiFi Registry Setup Guide

## Overview

NiFi Registry provides versioned flow storage for Apache NiFi 2.x. This guide explains how to configure and use the Registry for flow management.

---

## Architecture

```
NiFi (8443) <--> NiFi Registry (18080) <--> PostgreSQL (5432)
```

**Components:**
- **NiFi Registry**: Stores flow versions in PostgreSQL database
- **PostgreSQL**: Persistence layer for flow metadata and versions
- **NiFi**: Connects to Registry for version control

---

## Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| NiFi Registry UI | http://localhost:18080/nifi-registry/ | Flow version management |
| NiFi UI | https://localhost:8443/nifi/ | Flow design and execution |

**Credentials:**
- NiFi: `admin` / `supersecret1`
- NiFi Registry: No authentication (demo mode)

---

## Initial Configuration

### Step 1: Connect NiFi to Registry

1. **Open NiFi UI**: https://localhost:8443/nifi/

2. **Access Registry Clients**:
   - Click hamburger menu (☰) → Controller Settings
   - Navigate to "Registry Clients" tab
   - Click "+" to add new client

3. **Configure Registry Client**:
   ```
   Name: Demo Registry
   Type: NiFiRegistryFlowRegistryClient
   URL: http://nifi-registry:18080
   Description: Local NiFi Registry for flow versioning
   ```

4. **Save** and close the dialog

---

### Step 2: Create a Bucket in Registry

1. **Open NiFi Registry UI**: http://localhost:18080/nifi-registry/

2. **Create Bucket**:
   - Click wrench icon (⚙️) → New Bucket
   - Bucket Name: `demo-flows`
   - Description: `Demonstration flows for data lakehouse`
   - Click "CREATE"

---

### Step 3: Version Control a Flow

1. **In NiFi UI**, right-click on Process Group

2. **Select "Version" → "Start version control"**

3. **Configure Version Control**:
   ```
   Registry: Demo Registry
   Bucket: demo-flows
   Flow Name: orders-ingestion
   Flow Description: Ingest orders from CSV to Kafka
   Comments: Initial version
   ```

4. **Save** - Flow is now version controlled ✅

---

## Common Operations

### Save Flow Changes

1. Right-click Process Group
2. Select "Version" → "Commit local changes"
3. Add commit message describing changes
4. Click "SAVE"

### Revert to Previous Version

1. Right-click Process Group
2. Select "Version" → "Show local changes"
3. Click "Revert local changes" if needed

### Change Flow to Different Version

1. Right-click Process Group
2. Select "Version" → "Change version"
3. Select desired version from dropdown
4. Click "CHANGE"

### Import Flow from Registry

1. Drag Process Group onto canvas
2. Select "Import from Registry"
3. Choose Registry → Bucket → Flow → Version
4. Click "ADD"

---

## Flow Storage Structure

```
PostgreSQL (nifi_registry database)
  ├── Buckets (containers for flows)
  │   └── demo-flows
  ├── Flows (versioned process groups)
  │   ├── orders-ingestion
  │   ├── fraud-detection
  │   └── data-quality
  └── Versions (snapshots with metadata)
      ├── v1 (Initial version)
      ├── v2 (Added error handling)
      └── v3 (Performance improvements)
```

---

## Best Practices

### Bucket Organization

**By Environment:**
```
- dev-flows
- staging-flows
- prod-flows
```

**By Domain:**
```
- sales-flows
- marketing-flows
- operations-flows
```

**By Function:**
```
- ingestion-flows
- transformation-flows
- monitoring-flows
```

### Commit Messages

**Good commit messages:**
- ✅ "Add error handling for Kafka connection failures"
- ✅ "Increase batch size from 1000 to 5000 records"
- ✅ "Fix schema validation for customer table"

**Bad commit messages:**
- ❌ "Update"
- ❌ "Changes"
- ❌ "Fix bug"

### Versioning Strategy

1. **Major version (v1.0.0 → v2.0.0)**: Breaking changes, new flows
2. **Minor version (v1.0.0 → v1.1.0)**: New features, enhancements
3. **Patch version (v1.0.0 → v1.0.1)**: Bug fixes, configuration changes

---

## Troubleshooting

### Issue: "Registry client not available"

**Cause:** NiFi cannot reach Registry

**Solution:**
```bash
# Check if Registry is running
docker ps | grep nifi-registry

# Check Registry logs
docker logs nifi-registry

# Restart Registry
docker restart nifi-registry
```

---

### Issue: "Failed to save flow version"

**Cause:** Database connection error

**Solution:**
```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Check Registry can connect to database
docker logs nifi-registry | grep -i "database\|postgres"

# Verify database exists
docker exec postgres psql -U iceberg -d nifi_registry -c "SELECT 1;"
```

---

### Issue: "Bucket not found"

**Cause:** Bucket deleted or incorrect name

**Solution:**
1. Open Registry UI: http://localhost:18080/nifi-registry/
2. Verify bucket exists
3. Create bucket if needed
4. Update Registry client configuration in NiFi

---

## Registry Database Schema

View Registry metadata:

```sql
-- Connect to PostgreSQL
docker exec -it postgres psql -U iceberg -d nifi_registry

-- List all buckets
SELECT bucket_id, name, description, created
FROM bucket
ORDER BY created DESC;

-- List all flows
SELECT flow_id, name, description, created, modified
FROM flow
ORDER BY modified DESC;

-- List flow versions
SELECT flow_id, version, created, created_by, comments
FROM flow_version
ORDER BY created DESC
LIMIT 10;
```

---

## Backup and Recovery

### Backup Registry Data

```bash
# Backup PostgreSQL database
docker exec postgres pg_dump -U iceberg nifi_registry > nifi_registry_backup.sql

# Backup flow storage volume
docker run --rm -v nifi_registry_flow_storage:/data -v $(pwd):/backup \
    alpine tar czf /backup/nifi_registry_flows.tar.gz -C /data .
```

### Restore Registry Data

```bash
# Restore PostgreSQL database
cat nifi_registry_backup.sql | docker exec -i postgres psql -U iceberg nifi_registry

# Restore flow storage volume
docker run --rm -v nifi_registry_flow_storage:/data -v $(pwd):/backup \
    alpine sh -c "cd /data && tar xzf /backup/nifi_registry_flows.tar.gz"
```

---

## API Access

NiFi Registry exposes REST API for automation:

```bash
# List all buckets
curl http://localhost:18080/nifi-registry-api/buckets

# List flows in bucket
curl http://localhost:18080/nifi-registry-api/buckets/{bucketId}/flows

# Get flow version
curl http://localhost:18080/nifi-registry-api/buckets/{bucketId}/flows/{flowId}/versions/{version}
```

---

## Migration from NiFi 1.x Templates

**NiFi 1.x (Templates):**
- XML files imported via UI
- No version control
- Manual tracking

**NiFi 2.x (Registry):**
- Database-backed storage
- Full version history
- Git-like workflow

**Migration Steps:**

1. Export template from NiFi 1.x as XML
2. Import template into NiFi 2.x
3. Convert template to Process Group
4. Start version control on Process Group
5. Commit to Registry

---

## Performance Tuning

### Registry Configuration

Edit `docker/.env`:

```bash
# Increase connection pool
NIFI_REGISTRY_DB_MAX_CONNECTIONS=20

# Adjust timeout
NIFI_REGISTRY_DB_CONNECTION_TIMEOUT=30s
```

### Database Optimization

```sql
-- Create indexes for better performance
CREATE INDEX idx_flow_modified ON flow(modified);
CREATE INDEX idx_flow_version_created ON flow_version(created);

-- Analyze tables
ANALYZE bucket;
ANALYZE flow;
ANALYZE flow_version;
```

---

## Security Considerations

**Current Setup (Demo):**
- ✅ Registry accessible only via Docker network
- ✅ Database credentials in environment variables
- ❌ No authentication on Registry UI
- ❌ HTTP (not HTTPS)

**Production Recommendations:**
1. Enable HTTPS with valid certificates
2. Configure authentication (LDAP, OAuth, etc.)
3. Implement authorization policies
4. Restrict network access
5. Encrypt database connections
6. Use secrets management (Vault, AWS Secrets Manager)

---

## Next Steps

1. **Create your first versioned flow**:
   - Design a simple flow (GetFile → PutFile)
   - Save it to Registry
   - Make changes and commit new version

2. **Explore version history**:
   - View differences between versions
   - Revert to previous version
   - Branch flows for testing

3. **Automate with CI/CD**:
   - Export flows via Registry API
   - Store in Git repository
   - Deploy to different environments

---

**Document Version:** 1.0
**Last Updated:** 2026-02-05
**Maintainer:** Data Engineering Team
