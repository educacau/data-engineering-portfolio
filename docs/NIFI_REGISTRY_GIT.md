# NiFi Registry Git Integration

This document describes the Git integration configuration for Apache NiFi Registry, enabling version control for flow definitions.

## Architecture

**Hybrid Configuration:** Git + PostgreSQL Database

| Component | Purpose | Storage |
|-----------|---------|---------|
| **Git** | Flow snapshots and version control | `/opt/nifi-registry/flow-storage` |
| **PostgreSQL** | Metadata, buckets, permissions | `nifi_registry` database |

## Benefits

✅ **Version Control**
- Every flow change is committed to Git
- Full history of modifications
- Easy rollback to previous versions

✅ **Collaboration**
- Multiple team members can work on flows
- Review changes via Git tools
- Merge conflicts are handled

✅ **Backup & Recovery**
- Flows are stored in Git repository
- Can be cloned/backed up easily
- Disaster recovery is simplified

✅ **CI/CD Integration**
- Flows can be deployed via Git
- Automated testing of flow changes
- GitOps workflows possible

## Configuration Files

### 1. providers.xml
Located at: `docker/nifi-registry/conf/providers.xml`

```xml
<flowPersistenceProvider>
    <class>org.apache.nifi.registry.provider.flow.git.GitFlowPersistenceProvider</class>
    <property name="Flow Storage Directory">/opt/nifi-registry/flow-storage</property>
    <property name="Remote To Push">origin</property>
</flowPersistenceProvider>
```

### 2. docker-compose.yml
Environment variables for Git:
```yaml
environment:
  GIT_AUTHOR_NAME: NiFi Registry
  GIT_AUTHOR_EMAIL: nifi-registry@localhost
  GIT_COMMITTER_NAME: NiFi Registry
  GIT_COMMITTER_EMAIL: nifi-registry@localhost
```

Volume mounts:
```yaml
volumes:
  - nifi_registry_flow_storage:/opt/nifi-registry/flow-storage
  - ./nifi-registry/conf/providers.xml:/opt/nifi-registry/nifi-registry-current/conf/providers.xml:ro
```

## How It Works

### Flow Commit Workflow

1. **User saves a flow** in NiFi
2. **NiFi pushes to Registry** via REST API
3. **Registry saves snapshot** to Git repository
4. **Git commits the change** with metadata
5. **Database stores** bucket/flow metadata

### Git Repository Structure

```
/opt/nifi-registry/flow-storage/
├── .git/                    # Git metadata
├── README.md               # Repository documentation
└── [bucket-id]/            # One directory per bucket
    └── [flow-id]/          # One directory per flow
        ├── [version-1].snapshot  # Flow snapshot v1
        ├── [version-2].snapshot  # Flow snapshot v2
        └── ...
```

### Commit Messages

Format: `Create flow '{flow-name}' in bucket '{bucket-name}'`

Example:
```
Create flow 'Ingest Orders' in bucket 'Production Flows'

Created by: admin
Comments: Initial version of order ingestion pipeline
```

## Usage

### Creating a Versioned Flow

1. Open NiFi: `https://localhost:8443/nifi`
2. Create a Process Group
3. Right-click → **Version → Start version control**
4. Select Registry: `http://nifi-registry:18080`
5. Choose bucket and enter flow name
6. Click **Save**

✅ Flow is now versioned in Git!

### Viewing Git History

**Inside the container:**
```bash
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log --oneline
```

**Copy repository to local:**
```bash
docker cp nifi-registry:/opt/nifi-registry/flow-storage ./nifi-flows-backup
cd nifi-flows-backup
git log --graph --oneline --all
```

### Exporting Flow Repository

**Backup entire repository:**
```bash
# Create tarball
docker exec nifi-registry tar czf /tmp/flows.tar.gz -C /opt/nifi-registry flow-storage

# Copy to host
docker cp nifi-registry:/tmp/flows.tar.gz ./flows-backup.tar.gz

# Extract
tar xzf flows-backup.tar.gz
```

**Clone to new Registry:**
```bash
# Copy repository to new container
docker cp flow-storage nifi-registry-new:/opt/nifi-registry/

# Restart container
docker compose restart nifi-registry-new
```

## Advanced Configuration

### Remote Git Repository (GitHub/GitLab)

To push flows to a remote repository:

1. **Update providers.xml:**
```xml
<property name="Remote To Push">origin</property>
<property name="Remote Clone Repository">https://github.com/user/nifi-flows.git</property>
<property name="Remote Access User">github-user</property>
<property name="Remote Access Password">github-token</property>
```

2. **Rebuild and restart:**
```bash
docker compose build nifi-registry
docker compose up -d nifi-registry
```

### Git Hooks

Add pre-commit hooks for validation:

```bash
docker exec -it nifi-registry bash

cat > /opt/nifi-registry/flow-storage/.git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Validate flow snapshots before commit
echo "Validating flow snapshots..."
# Add validation logic here
exit 0
EOF

chmod +x /opt/nifi-registry/flow-storage/.git/hooks/pre-commit
```

## Troubleshooting

### Check Git Configuration
```bash
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage config --list
```

### View Recent Commits
```bash
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage log -5 --oneline
```

### Check Git Status
```bash
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage status
```

### Verify Providers Configuration
```bash
docker exec nifi-registry cat /opt/nifi-registry/nifi-registry-current/conf/providers.xml
```

### Common Issues

**Issue:** "Failed to save flow - Git error"
```bash
# Check Git initialization
docker exec nifi-registry ls -la /opt/nifi-registry/flow-storage/.git

# Reinitialize if needed
docker exec nifi-registry git -C /opt/nifi-registry/flow-storage init
```

**Issue:** "Permission denied"
```bash
# Fix ownership
docker exec -u root nifi-registry chown -R nifi:nifi /opt/nifi-registry/flow-storage
```

**Issue:** "No such file or directory"
```bash
# Verify volume mount
docker exec nifi-registry ls -la /opt/nifi-registry/flow-storage
```

## Migration from Database-Only

If you're migrating from database-only persistence:

1. **Export existing flows** via NiFi Registry UI
2. **Apply Git configuration** (this setup)
3. **Restart NiFi Registry**
4. **Re-import flows** - they'll now be Git-backed
5. **Verify** Git commits are being created

## Comparison: Git vs Database

| Feature | Git Provider | Database Provider |
|---------|--------------|-------------------|
| Version Control | ✅ Full Git history | ⚠️ Limited (DB versions) |
| Backup/Recovery | ✅ Git clone | ⚠️ DB dumps |
| Collaboration | ✅ Git workflows | ❌ No merge support |
| Performance | ✅ Fast (local) | ✅ Fast (cached) |
| Storage | 📁 File system | 💾 PostgreSQL |
| CI/CD Integration | ✅ Native Git | ⚠️ Custom scripts |

## Best Practices

1. **Regular Backups:** Clone the Git repository periodically
2. **Commit Messages:** Use descriptive flow/bucket names
3. **Remote Repository:** Push to GitHub/GitLab for off-site backup
4. **Access Control:** Use database for user permissions
5. **Monitoring:** Watch disk usage of flow-storage volume

## References

- [NiFi Registry Administration Guide](https://nifi.apache.org/docs/nifi-registry-docs/html/administration-guide.html)
- [Git Flow Persistence Provider](https://nifi.apache.org/docs/nifi-registry-docs/html/administration-guide.html#gitflowpersistenceprovider)
- [NiFi Version Control](https://nifi.apache.org/docs/nifi-docs/html/user-guide.html#versioning-dataflow)
