# Operations Runbook - Apache NiFi Data Lakehouse

## Table of Contents
- [Quick Reference](#quick-reference)
- [Startup Procedures](#startup-procedures)
- [Shutdown Procedures](#shutdown-procedures)
- [Monitoring](#monitoring)
- [Backup & Recovery](#backup--recovery)
- [Scaling](#scaling)
- [Common Operations](#common-operations)

---

## Quick Reference

### Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| NiFi UI | https://localhost:8443/nifi/ | admin / supersecret1 |
| Superset | http://localhost:8088/ | admin / admin |
| Jupyter Lab | http://localhost:8888/ | Password: supersecret1 |
| Trino UI | http://localhost:8080/ui/ | No auth |
| MinIO Console | http://localhost:9001/ | minio / CHANGE_ME_minio123 |
| Grafana | http://localhost:3000/ | admin / admin |

### Essential Commands

```bash
# Start demo mode
./demo.sh

# Start full stack
docker compose -f docker/docker-compose.yml up -d

# Check service status
docker ps

# View logs
docker compose -f docker/docker-compose.yml logs -f [service]

# Stop all services
docker compose -f docker/docker-compose.yml down

# Restart specific service
docker restart [service-name]
```

---

## Startup Procedures

### Demo Mode (< 5 minutes, < 4GB RAM)

**Purpose:** Quick demonstration, development, testing

```bash
# 1. Ensure Docker is running
docker info

# 2. Check available resources
docker system df

# 3. Run demo script
./demo.sh

# 4. Wait for health checks (automatic)
# Script will display access URLs when ready
```

**Expected Output:**
```
[SUCCESS] All services healthy
[INFO] Access URLs:
  NiFi:     https://localhost:8443/nifi/
  Superset: http://localhost:8088/
  ...
```

### Full Stack (10-15 minutes, ~12GB RAM)

**Purpose:** Production-like environment with all features

```bash
# 1. Start with full profile
docker compose -f docker/docker-compose.yml --profile full up -d

# 2. Monitor startup progress
docker compose -f docker/docker-compose.yml logs -f

# 3. Check service health
docker ps --filter "health=healthy"

# 4. Verify all containers running
docker ps | wc -l  # Should show 15+ containers
```

### Startup Troubleshooting

**If services fail to start:**

1. **Check Docker resources:**
   ```bash
   docker system df
   docker system prune -a  # Free space if needed
   ```

2. **Check port conflicts:**
   ```bash
   netstat -tuln | grep -E '8080|8088|8443|8888|9001'
   ```

3. **View specific service logs:**
   ```bash
   docker logs [service-name] --tail 100
   ```

4. **Restart problematic service:**
   ```bash
   docker restart [service-name]
   ```

---

## Shutdown Procedures

### Graceful Shutdown

**Recommended for preserving data and state:**

```bash
# 1. Stop accepting new data (optional)
# Stop NiFi flows manually through UI

# 2. Allow in-flight data to complete
sleep 60

# 3. Stop all services
docker compose -f docker/docker-compose.yml down

# 4. Verify all stopped
docker ps -a | grep data-lakehouse
```

### Force Shutdown

**Use only when necessary:**

```bash
# Stop and remove all containers immediately
docker compose -f docker/docker-compose.yml down --timeout 10

# If containers are stuck
docker ps -q | xargs docker kill
```

### Cleanup (Development Only)

**WARNING:** This deletes all data!

```bash
# Remove containers, networks, volumes
docker compose -f docker/docker-compose.yml down -v

# Remove generated data
rm -rf demo/data/output/*

# Remove dangling images
docker image prune -f
```

---

## Monitoring

### Health Checks

**Check all services:**
```bash
# Using docker ps
docker ps --format "table {{.Names}}\t{{.Status}}"

# Detailed health status
docker inspect --format='{{.Name}}: {{.State.Health.Status}}' $(docker ps -q)
```

**Individual service health endpoints:**
```bash
# Trino
curl http://localhost:8080/v1/info | jq .

# Superset
curl http://localhost:8088/health

# MinIO
curl http://localhost:9000/minio/health/live
```

### Resource Usage

**Monitor CPU and memory:**
```bash
# Real-time stats
docker stats

# Check specific container
docker stats [container-name] --no-stream

# Memory usage summary
docker ps -q | xargs docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"
```

**Disk usage:**
```bash
# Docker disk usage
docker system df -v

# Volume sizes
docker volume ls -q | xargs docker volume inspect --format '{{ .Name }}: {{ .Mountpoint }}' | while read vol; do echo "$vol ($(du -sh $(echo $vol | cut -d: -f2) 2>/dev/null | cut -f1))"; done
```

### Log Monitoring

**View logs:**
```bash
# All services
docker compose -f docker/docker-compose.yml logs -f

# Specific service
docker logs -f [service-name]

# Last N lines
docker logs --tail 100 [service-name]

# With timestamps
docker logs -t [service-name]

# Follow and grep
docker logs -f nifi-1 | grep ERROR
```

**Export logs:**
```bash
# Save logs to file
docker logs [service-name] > logs/[service]-$(date +%Y%m%d).log

# Export all logs
docker compose -f docker/docker-compose.yml logs > logs/all-services-$(date +%Y%m%d).log
```

---

## Backup & Recovery

### Backup Procedures

**1. Backup persistent data:**
```bash
#!/bin/bash
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup MinIO data (Iceberg tables)
docker run --rm -v minio_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/minio-data.tar.gz -C /data .

# Backup PostgreSQL (Iceberg catalog)
docker exec postgres pg_dump -U iceberg iceberg_catalog > "$BACKUP_DIR/postgres-catalog.sql"

# Backup NiFi configuration
docker run --rm -v nifi_conf_1:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/nifi-conf.tar.gz -C /data .

# Backup Superset metadata
docker run --rm -v superset_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine tar czf /backup/superset-data.tar.gz -C /data .

echo "Backup completed: $BACKUP_DIR"
```

**2. Backup to cloud (example):**
```bash
# Upload to S3
aws s3 sync backups/ s3://my-lakehouse-backups/

# Upload to GCS
gsutil -m rsync -r backups/ gs://my-lakehouse-backups/
```

### Recovery Procedures

**1. Restore from backup:**
```bash
#!/bin/bash
BACKUP_DIR="backups/20260204_120000"  # Specify backup timestamp

# Stop services
docker compose -f docker/docker-compose.yml down

# Restore MinIO data
docker run --rm -v minio_data:/data -v $(pwd)/$BACKUP_DIR:/backup alpine sh -c "cd /data && tar xzf /backup/minio-data.tar.gz"

# Restore PostgreSQL
cat "$BACKUP_DIR/postgres-catalog.sql" | docker exec -i postgres psql -U iceberg iceberg_catalog

# Restore NiFi configuration
docker run --rm -v nifi_conf_1:/data -v $(pwd)/$BACKUP_DIR:/backup alpine sh -c "cd /data && tar xzf /backup/nifi-conf.tar.gz"

# Restart services
docker compose -f docker/docker-compose.yml up -d

echo "Recovery completed from: $BACKUP_DIR"
```

**2. Disaster recovery (new environment):**
```bash
# 1. Clone repository
git clone <repo-url>
cd data-engineering-portfolio

# 2. Download backups from cloud
aws s3 sync s3://my-lakehouse-backups/latest/ backups/latest/

# 3. Run recovery script
./scripts/restore-from-backup.sh backups/latest/

# 4. Verify data
docker exec -it trino trino
trino> SELECT COUNT(*) FROM iceberg.lakehouse.orders;
```

---

## Scaling

### Horizontal Scaling

**Add Trino workers:**
```bash
# Scale Trino workers to 3
docker compose -f docker/docker-compose.yml up -d --scale trino-worker=3

# Verify
docker ps | grep trino-worker
```

**Add NiFi nodes (requires cluster mode):**
```bash
# Start with full profile for 3-node NiFi cluster
docker compose -f docker/docker-compose.yml --profile full up -d
```

### Vertical Scaling

**Increase heap memory:**

Edit `docker-compose.yml`:
```yaml
environment:
  NIFI_JVM_HEAP_INIT: 4g  # Increase from 2g
  NIFI_JVM_HEAP_MAX: 4g
```

**Increase worker resources:**
```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'
      memory: 8G
    reservations:
      cpus: '2.0'
      memory: 4G
```

### Performance Tuning

**Trino query performance:**
```bash
# Increase query memory
docker exec trino sed -i 's/query.max-memory=2GB/query.max-memory=4GB/' /etc/trino/config.properties
docker restart trino
```

**Kafka throughput:**
```bash
# Increase partitions for high-volume topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --alter --topic orders --partitions 12
```

---

## Common Operations

### Data Management

**Check table sizes:**
```sql
-- In Trino
SELECT
    table_name,
    SUM(file_size_in_bytes) / 1024 / 1024 / 1024 AS size_gb,
    COUNT(*) AS file_count
FROM "orders$files"
GROUP BY table_name;
```

**Compact small files:**
```sql
-- Iceberg table maintenance
ALTER TABLE orders EXECUTE optimize;
```

**Expire old snapshots:**
```sql
-- Keep last 7 days
ALTER TABLE orders EXECUTE expire_snapshots(retention_threshold => '7d');
```

### User Management

**NiFi:**
```bash
# View current users (check logs)
docker logs nifi-1 | grep "Generated Username"

# Change password (requires restart)
docker exec nifi-1 /opt/nifi/nifi-current/bin/nifi.sh set-single-user-credentials admin newpassword123
docker restart nifi-1
```

**Superset:**
```bash
# Create new admin user
docker exec superset superset fab create-admin \
    --username newadmin \
    --firstname Admin \
    --lastname User \
    --email admin@example.com \
    --password newpassword

# List users
docker exec superset superset fab list-users
```

### Certificate Management

**Regenerate NiFi self-signed certificate:**
```bash
# Remove existing cert
docker exec nifi-1 rm -rf /opt/nifi/nifi-current/conf/keystore.jks

# Restart to regenerate
docker restart nifi-1
```

---

## Maintenance Schedule

### Daily
- Check service health
- Monitor disk usage
- Review error logs

### Weekly
- Backup persistent volumes
- Check for security updates
- Review performance metrics

### Monthly
- Update Docker images
- Expire old Iceberg snapshots
- Compact small files
- Review and clean up logs

### Quarterly
- Full disaster recovery test
- Security audit
- Performance benchmark comparison

---

## Emergency Contacts

**For production issues:**
- On-call engineer: [Contact info]
- DevOps team: [Slack channel]
- Database admin: [Contact info]

**Escalation:**
1. Check logs and troubleshooting guide
2. Contact on-call engineer
3. Escalate to DevOps team lead
4. Page senior engineer if critical

---

**Document Version:** 1.0
**Last Updated:** 2026-02-04
**Owner:** Data Engineering Team
