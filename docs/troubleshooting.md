# Troubleshooting Guide - Apache NiFi Data Lakehouse

## Table of Contents
- [Quick Diagnosis](#quick-diagnosis)
- [Service-Specific Issues](#service-specific-issues)
- [Common Error Messages](#common-error-messages)
- [Performance Issues](#performance-issues)
- [Data Quality Issues](#data-quality-issues)

---

## Quick Diagnosis

### Health Check Workflow

```bash
# 1. Check if Docker is running
docker info || echo "Docker is not running!"

# 2. Check which containers are running
docker ps

# 3. Check which containers failed
docker ps -a --filter "status=exited"

# 4. Check resource usage
docker stats --no-stream

# 5. Check logs for errors
docker compose -f docker/docker-compose.yml logs | grep -i error
```

---

## Service-Specific Issues

### NiFi

#### Problem: NiFi UI not accessible (ERR_CONNECTION_REFUSED)

**Symptoms:**
- Cannot access https://localhost:8443/nifi/
- Browser shows connection refused

**Diagnosis:**
```bash
# Check if NiFi container is running
docker ps | grep nifi

# Check NiFi logs
docker logs nifi-1 --tail 100

# Check if port is exposed
docker port nifi-1
```

**Solutions:**

1. **Wait for startup** (NiFi takes 2-5 minutes):
   ```bash
   docker logs -f nifi-1 | grep "Started Server"
   ```

2. **Check health status:**
   ```bash
   docker inspect nifi-1 | grep -A 5 Health
   ```

3. **Restart if unhealthy:**
   ```bash
   docker restart nifi-1
   ```

4. **Check certificate (HTTPS):**
   ```bash
   curl -k https://localhost:8443/nifi/
   ```

---

#### Problem: NiFi login credentials not working

**Symptoms:**
- "Invalid username/password" message
- Cannot find generated credentials

**Solutions:**

1. **Find generated credentials:**
   ```bash
   docker logs nifi-1 2>&1 | grep "Generated Username"
   ```

2. **Reset credentials:**
   ```bash
   docker exec nifi-1 /opt/nifi/nifi-current/bin/nifi.sh \
       set-single-user-credentials admin changeme123
   docker restart nifi-1
   ```

---

#### Problem: NiFi cluster nodes not forming

**Symptoms:**
- Only 1 NiFi node visible
- "Failed to determine elected Cluster Coordinator" in logs

**Diagnosis:**
```bash
docker logs nifi-1 2>&1 | grep -i cluster
docker logs nifi-2 2>&1 | grep -i cluster
```

**Solutions:**

1. **Check if running with full profile:**
   ```bash
   docker ps | grep nifi | wc -l  # Should show 3
   ```

2. **Start with full profile:**
   ```bash
   docker compose -f docker/docker-compose.yml down
   docker compose -f docker/docker-compose.yml --profile full up -d
   ```

3. **Check ZooKeeper connectivity:**
   ```bash
   docker exec nifi-2 nc -zv zookeeper 2181
   ```

---

### Trino

#### Problem: Trino queries timing out

**Symptoms:**
- Queries take > 30 seconds
- "Query exceeded maximum time" error

**Diagnosis:**
```bash
# Check query queue
curl -s http://localhost:8080/v1/query | jq '.[] | {state, query}'

# Check worker status
curl -s http://localhost:8080/v1/node | jq '.[] | {uri, recentFailures}'
```

**Solutions:**

1. **Increase query timeout:**
   ```bash
   # In Trino CLI
   SET SESSION query_max_run_time = '10m';
   ```

2. **Check memory pressure:**
   ```bash
   docker stats trino --no-stream
   ```

3. **Optimize query:**
   ```sql
   EXPLAIN SELECT ...;  -- Check execution plan
   ```

---

#### Problem: Trino cannot connect to Iceberg catalog

**Symptoms:**
- "Catalog 'iceberg' does not exist"
- "Cannot connect to PostgreSQL"

**Diagnosis:**
```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Check Trino can reach PostgreSQL
docker exec trino curl postgres:5432

# Check catalog configuration
docker exec trino cat /etc/trino/catalog/iceberg.properties
```

**Solutions:**

1. **Verify PostgreSQL credentials:**
   ```bash
   docker exec postgres psql -U iceberg -d iceberg_catalog -c "SELECT 1;"
   ```

2. **Restart Trino:**
   ```bash
   docker restart trino
   ```

3. **Check Iceberg connector logs:**
   ```bash
   docker logs trino 2>&1 | grep -i iceberg
   ```

---

### Superset

#### Problem: HTTP 500 error on login

**Symptoms:**
- "Internal Server Error" when accessing UI
- "no such table: user_attribute" in logs

**Diagnosis:**
```bash
docker logs superset 2>&1 | tail -50
```

**Solution:**

1. **Initialize database:**
   ```bash
   docker exec superset superset db upgrade
   docker exec superset superset init
   ```

2. **Recreate admin user:**
   ```bash
   docker exec superset superset fab create-admin \
       --username admin \
       --firstname Admin \
       --lastname User \
       --email admin@superset.com \
       --password admin
   ```

---

#### Problem: Cannot connect Superset to Trino

**Symptoms:**
- "Could not connect to database" when adding Trino connection
- Connection test fails

**Solutions:**

1. **Use correct SQLAlchemy URI:**
   ```
   trino://trino:8080/iceberg/lakehouse
   ```

2. **Check Trino is accessible:**
   ```bash
   docker exec superset curl http://trino:8080/v1/info
   ```

3. **Install Trino driver (if needed):**
   ```bash
   docker exec superset pip install trino
   docker restart superset
   ```

---

### Jupyter Lab

#### Problem: Cannot access Jupyter (redirects to login)

**Symptoms:**
- Redirected to password/token login page
- Token from docs doesn't work

**Solutions:**

1. **Use correct password:**
   ```
   Password: supersecret1
   ```

2. **Find current token (if password fails):**
   ```bash
   docker logs jupyter 2>&1 | grep token=
   ```

3. **Reset password:**
   ```bash
   docker exec jupyter jupyter server password
   # Enter new password when prompted
   docker restart jupyter
   ```

---

### MinIO

#### Problem: Cannot login to MinIO console

**Symptoms:**
- "Invalid Access Key or Secret Key" error
- Credentials don't work

**Solutions:**

1. **Use correct credentials:**
   ```
   Username: minio
   Password: CHANGE_ME_minio123
   ```

2. **Check environment variables:**
   ```bash
   docker exec minio printenv | grep MINIO_ROOT
   ```

3. **Reset credentials (requires restart):**
   ```bash
   # Edit docker-compose.yml, then:
   docker compose -f docker/docker-compose.yml up -d minio
   ```

---

### Kafka

#### Problem: Kafka broker not reachable

**Symptoms:**
- NiFi cannot publish to Kafka
- "Connection to node -1 could not be established"

**Diagnosis:**
```bash
# Check Kafka status
docker logs kafka --tail 100

# Test broker connectivity
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092
```

**Solutions:**

1. **Check ZooKeeper is running:**
   ```bash
   docker ps | grep zookeeper
   docker exec kafka nc -zv zookeeper 2181
   ```

2. **Restart Kafka:**
   ```bash
   docker restart kafka
   ```

3. **Check topics exist:**
   ```bash
   docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
   ```

---

## Common Error Messages

### "no space left on device"

**Cause:** Docker volumes or host disk full

**Solution:**
```bash
# Check disk usage
df -h
docker system df

# Clean up
docker system prune -a --volumes
docker volume prune
```

---

### "port is already allocated"

**Cause:** Port conflict with another service

**Solution:**
```bash
# Find process using port
netstat -tuln | grep 8080
lsof -i :8080  # macOS/Linux

# Kill process or change port in docker-compose.yml
```

---

### "OOM killed"

**Cause:** Container exceeded memory limit

**Solution:**
```bash
# Check memory limits
docker inspect [container] | grep Memory

# Increase memory in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 4G  # Increase from 2G
```

---

### "network not found"

**Cause:** Docker networks not created

**Solution:**
```bash
# Recreate networks
docker compose -f docker/docker-compose.yml down
docker compose -f docker/docker-compose.yml up -d
```

---

## Performance Issues

### Slow Query Performance

**Symptoms:** Queries take > 5 seconds

**Diagnosis:**
```sql
-- Check query execution plan
EXPLAIN SELECT ...;

-- Check table statistics
SHOW STATS FOR orders;
```

**Solutions:**

1. **Add partition pruning:**
   ```sql
   WHERE order_date >= DATE '2026-01-01'  -- Uses partition
   ```

2. **Compact small files:**
   ```sql
   ALTER TABLE orders EXECUTE optimize;
   ```

3. **Increase Trino memory:**
   Edit `docker/trino/config.properties`:
   ```properties
   query.max-memory=4GB  # Increase from 2GB
   ```

---

### High Memory Usage

**Symptoms:** Docker using > 8GB RAM

**Diagnosis:**
```bash
docker stats --format "table {{.Name}}\t{{.MemUsage}}"
```

**Solutions:**

1. **Reduce heap sizes in docker-compose.yml:**
   ```yaml
   NIFI_JVM_HEAP_MAX: 1.5g  # Reduce from 2g
   ```

2. **Use demo profile:**
   ```bash
   docker compose -f docker/docker-compose.yml down
   ./demo.sh  # Uses optimized demo profile
   ```

3. **Stop unused services:**
   ```bash
   docker stop grafana prometheus loki  # If not needed
   ```

---

### Container Keeps Restarting

**Symptoms:** Container restarts every few seconds

**Diagnosis:**
```bash
# Check restart count
docker ps -a | grep [container-name]

# Check exit code
docker inspect [container-name] | grep -A 5 State

# Check logs
docker logs [container-name] --tail 100
```

**Solutions:**

1. **Check health check:**
   ```bash
   docker exec [container-name] curl localhost:[port]/health
   ```

2. **Disable health check temporarily:**
   Comment out `healthcheck` in docker-compose.yml

3. **Increase start period:**
   ```yaml
   healthcheck:
     start_period: 300s  # Increase from 120s
   ```

---

## Data Quality Issues

### Missing Data in Tables

**Symptoms:** `SELECT COUNT(*)` returns 0 or unexpected value

**Diagnosis:**
```sql
-- Check table exists
SHOW TABLES FROM iceberg.lakehouse;

-- Check snapshots
SELECT * FROM "orders$snapshots";

-- Check files
SELECT * FROM "orders$files";
```

**Solutions:**

1. **Regenerate data:**
   ```bash
   python demo/data/generate.py --volume 100000 --output demo/data/output/
   ```

2. **Check data was loaded:**
   ```bash
   ls -lh demo/data/output/
   ```

3. **Verify Spark job completed:**
   ```bash
   docker logs spark-worker
   ```

---

### Schema Mismatch Errors

**Symptoms:** "Column 'X' does not exist" or type mismatch errors

**Diagnosis:**
```sql
-- Check current schema
DESCRIBE orders;

-- Check schema evolution history
SELECT * FROM "orders$snapshots";
```

**Solutions:**

1. **Verify data generator schema matches:**
   ```bash
   head -1 demo/data/output/orders.csv
   ```

2. **Drop and recreate table (development only):**
   ```sql
   DROP TABLE IF EXISTS orders;
   -- Recreate with correct schema
   ```

---

## Getting Help

If issues persist after trying these solutions:

1. **Check documentation:** [ARCHITECTURE.md](./ARCHITECTURE.md), [README.md](../README.md)
2. **Review logs:** Always check Docker logs for specific errors
3. **Search issues:** GitHub Issues tab for similar problems
4. **Ask for help:** Create new GitHub Issue with:
   - Error message
   - Steps to reproduce
   - Output of `docker ps` and `docker logs`
   - Environment details (OS, Docker version)

---

**Document Version:** 1.0
**Last Updated:** 2026-02-04
**Maintainer:** Data Engineering Team
