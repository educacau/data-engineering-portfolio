# Screenshot Capture Guide - Phase 3

This guide provides detailed instructions for capturing professional screenshots for the portfolio.

## Prerequisites

- All Phase 2 services running (`docker ps` shows all healthy)
- Screen resolution: 1920x1080 or higher
- Screenshot tool: Windows Snipping Tool, macOS Screenshot (Cmd+Shift+4), or Linux Flameshot

## Required Screenshots

### 1. NiFi Flow Canvas (`docs/images/nifi-flow.png`)

**URL:** https://localhost:8443/nifi/

**Credentials:**
- Username: `admin`
- Password: Check NiFi logs with `docker logs nifi-1 2>&1 | grep "Generated Username"`

**What to Capture:**
- Full NiFi canvas with active data flows
- Show processors in running state (green indicators)
- Include flow statistics (data in/out rates)
- Capture the toolbar and navigation

**Steps:**
1. Access NiFi UI
2. Import a flow template from `demo/flows/` (if available)
3. Start the flow (click "Start" in Operations menu)
4. Wait for data to flow (green indicators, non-zero statistics)
5. Zoom to fit entire canvas
6. Take screenshot at 1920x1080

**Expected File Size:** < 400KB after optimization

---

### 2. Superset Sales Dashboard (`docs/images/dashboard-sales.png`)

**URL:** http://localhost:8088/

**Credentials:**
- Username: `admin`
- Password: `admin`

**What to Capture:**
- Complete dashboard with multiple charts populated with data
- Show date range selector
- Include dashboard title and filters
- Capture charts showing actual data (not empty)

**Steps:**
1. Access Superset UI
2. Navigate to Dashboards
3. Import dashboard from `demo/dashboards/sales_overview.json` (if available) or create sample charts
4. Ensure all charts are loaded with data
5. Take full-page screenshot

**Expected File Size:** < 400KB after optimization

---

### 3. Fraud Detection Dashboard (`docs/images/dashboard-fraud.png`)

**URL:** http://localhost:8088/

**Credentials:** Same as Superset Sales Dashboard

**What to Capture:**
- Fraud detection metrics and anomaly alerts
- Charts showing suspicious patterns
- Color-coded indicators (red for alerts)

**Steps:**
1. Import fraud detection dashboard
2. Ensure data is populated
3. Take screenshot showing alerts and metrics

**Expected File Size:** < 400KB after optimization

---

### 4. Trino Query Interface (`docs/images/trino-query.png`)

**URL:** http://localhost:8080/ui/

**What to Capture:**
- Trino web UI showing a query in execution or completed
- Query results with data
- Query statistics (execution time, rows processed)

**Steps:**
1. Access Trino UI
2. Run a sample query from `demo/queries/` using CLI:
   ```bash
   docker exec -it trino trino
   trino> USE iceberg.lakehouse;
   trino> SELECT * FROM orders LIMIT 10;
   ```
3. Screenshot the query results in UI (queries page)

**Expected File Size:** < 300KB after optimization

---

### 5. Kafka UI (`docs/images/kafka-ui.png`)

**Option A: Kafka Control Center (if available)**
- URL: http://localhost:9021/

**Option B: Use kafka-topics command and screenshot output:**
```bash
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic orders --max-messages 10
```

**What to Capture:**
- List of Kafka topics
- Topic details (partitions, replicas)
- Consumer group information

**Expected File Size:** < 300KB after optimization

---

### 6. Jupyter Notebook Analysis (`docs/images/jupyter-analysis.png`)

**URL:** http://localhost:8888/

**Token:** Check with `docker logs jupyter 2>&1 | grep "token="`

**What to Capture:**
- Jupyter notebook with:
  - Code cells showing data analysis
  - Visualizations (matplotlib/seaborn charts)
  - DataFrames displayed as tables
- Show both code and output

**Steps:**
1. Access Jupyter Lab
2. Create new notebook
3. Run sample analysis:
   ```python
   import pandas as pd
   from trino.dbapi import connect

   conn = connect(host='trino', port=8080, catalog='iceberg', schema='lakehouse')
   df = pd.read_sql("SELECT region, SUM(total_amount) as revenue FROM orders GROUP BY region", conn)
   df.plot.bar(x='region', y='revenue', title='Revenue by Region')
   ```
4. Take screenshot showing code + visualization

**Expected File Size:** < 400KB after optimization

---

### 7. Grafana Monitoring Dashboard (`docs/images/grafana-dashboard.png`)

**Note:** Only if Prometheus/Grafana are enabled in docker-compose

**URL:** http://localhost:3000/

**Credentials:**
- Username: `admin`
- Password: `admin`

**What to Capture:**
- System monitoring dashboard
- Metrics graphs (CPU, memory, network)
- Service health indicators

**Expected File Size:** < 400KB after optimization

---

### 8. MinIO S3 Console (`docs/images/minio-console.png`)

**URL:** http://localhost:9001/

**Credentials:**
- Username: `minioadmin`
- Password: `minioadmin`

**What to Capture:**
- MinIO console showing buckets
- Bucket contents (show `lakehouse` bucket with Iceberg data)
- File browser view with directories

**Steps:**
1. Access MinIO console
2. Navigate to `lakehouse` bucket
3. Show directory structure (metadata, data folders)
4. Take screenshot

**Expected File Size:** < 300KB after optimization

---

## Screenshot Best Practices

### Resolution and Quality
- **Resolution:** 1920x1080 (Full HD)
- **Format:** PNG (lossless)
- **Color Depth:** 24-bit RGB
- **DPI:** 96 (standard screen DPI)

### Framing
- **Capture full browser window** or relevant UI section
- **Remove unnecessary browser tabs** or bookmarks bar
- **Center content** in the viewport
- **Show relevant context** (URL bar can be included for clarity)

### Timing
- **Wait for data to load** completely
- **Ensure charts render** before screenshot
- **Show active states** (running flows, executing queries)
- **Avoid loading spinners** or "no data" states

### File Management
1. Save screenshots to `docs/images/` with descriptive names
2. Use lowercase with hyphens: `nifi-flow.png`, `dashboard-sales.png`
3. Keep originals as backup before optimization
4. Run optimization script: `./scripts/optimize-images.sh docs/images/`

---

## Optimization Workflow

After capturing all screenshots:

```bash
# 1. Verify all screenshots are present
ls -lh docs/images/*.png

# 2. Check file sizes (should be > 500KB before optimization)
du -h docs/images/*.png

# 3. Run optimization script
chmod +x scripts/optimize-images.sh
./scripts/optimize-images.sh docs/images 400

# 4. Verify optimized sizes (should be < 400KB)
du -h docs/images/*.png

# 5. Visual quality check (open each file)
# Ensure no visible quality degradation
```

---

## Troubleshooting

### Screenshot is too large (> 500KB)
- Crop unnecessary whitespace
- Reduce resolution slightly (1600x900 acceptable)
- Run optimization script with lower target: `./scripts/optimize-images.sh docs/images 350`

### Screenshot is blurry after optimization
- Original quality too low (recapture at higher DPI)
- Optimization too aggressive (increase quality: edit script quality to 75-85)

### Service not showing data
- Check data generation: `ls -lh demo/data/output/`
- Verify ingestion: Check NiFi logs or Kafka topics
- Query data directly: `docker exec -it trino trino` then `SELECT COUNT(*) FROM iceberg.lakehouse.orders;`

### Browser UI looks unprofessional
- Use Chrome/Firefox in clean profile (no extensions)
- Zoom to 100% (Ctrl+0)
- Clear console warnings (F12 -> Console -> Clear)

---

## Next Steps

After capturing and optimizing all 8 screenshots:

1. **Update ARCHITECTURE.md** with embedded screenshots
2. **Update README.md** with hero image and key screenshots
3. **Create demo GIF** (30 seconds) showing workflow
4. **Commit visual assets** to repository

**Estimated Time:** 1-2 hours for all screenshots + optimization
