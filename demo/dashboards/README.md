# Superset Dashboards

This directory contains pre-configured Apache Superset dashboards for the Data Lakehouse demo.

## Dashboard List

1. **sales_overview.json** - Sales performance metrics
2. **fraud_detection.json** - Real-time fraud monitoring
3. **executive_summary.json** - High-level KPIs
4. **product_performance.json** - Product category analysis
5. **regional_analysis.json** - Geographic revenue breakdown

## How to Export Dashboards

After running the demo and creating dashboards in Superset:

1. Open Superset at http://localhost:8088
2. Navigate to Dashboards
3. Click on a dashboard
4. Click "..." menu > Export
5. Save JSON file to this directory

## How to Import Dashboards

```bash
# Via Superset UI
1. Open Superset
2. Go to Dashboards
3. Click "+" > Import Dashboard
4. Upload JSON file

# Via API (requires running Superset)
curl -X POST http://localhost:8088/api/v1/dashboard/import/ \
  -H "Content-Type: multipart/form-data" \
  -F "formData=@sales_overview.json"
```

## Dashboard Templates (To be created in Phase 3)

These dashboards will be created when the stack is running:

- Sales Overview: Revenue trends, top products, regional performance
- Fraud Detection: Anomaly alerts, risk scores, suspicious patterns
- Executive Summary: KPIs, growth metrics, customer acquisition
- Product Performance: Category analysis, inventory velocity
- Regional Analysis: Geographic heatmaps, comparative metrics
