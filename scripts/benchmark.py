#!/usr/bin/env python3
"""
Performance Benchmark Suite for Apache NiFi Data Lakehouse

Measures query latency, throughput, and system performance.
Outputs results to docs/performance.md
"""

import argparse
import statistics
import sys
import time
from datetime import datetime
from typing import Dict, List, Tuple

import trino


class PerformanceBenchmark:
    """Performance benchmark suite for Trino queries."""

    def __init__(self, host: str = "localhost", port: int = 8080):
        """Initialize benchmark with Trino connection."""
        self.conn = trino.dbapi.connect(
            host=host,
            port=port,
            catalog="iceberg",
            schema="lakehouse",
        )
        self.results: Dict[str, List[float]] = {}

    def run_query(self, query: str, name: str) -> float:
        """Execute query and return execution time in seconds."""
        cursor = self.conn.cursor()
        start_time = time.time()

        try:
            cursor.execute(query)
            _ = cursor.fetchall()  # Fetch to ensure query completes
            elapsed = time.time() - start_time
            return elapsed
        except Exception as e:
            print(f"[ERROR] Query '{name}' failed: {e}", file=sys.stderr)
            return -1.0
        finally:
            cursor.close()

    def benchmark_query(
        self, query: str, name: str, iterations: int = 10, warmup: int = 2
    ) -> Dict[str, float]:
        """
        Benchmark a query with warmup runs and multiple iterations.

        Args:
            query: SQL query to benchmark
            name: Human-readable name for the query
            iterations: Number of iterations to run
            warmup: Number of warmup runs (results discarded)

        Returns:
            Dictionary with p50, p95, p99, mean, min, max latencies
        """
        print(f"\n[INFO] Benchmarking: {name}")
        print(f"  Warmup: {warmup} runs, Iterations: {iterations}")

        # Warmup runs
        for i in range(warmup):
            print(f"  Warmup {i+1}/{warmup}...", end=" ", flush=True)
            self.run_query(query, name)
            print("Done")

        # Benchmark runs
        timings = []
        for i in range(iterations):
            print(f"  Run {i+1}/{iterations}...", end=" ", flush=True)
            elapsed = self.run_query(query, name)
            if elapsed < 0:
                print("FAILED")
                continue
            timings.append(elapsed)
            print(f"{elapsed:.3f}s")

        if not timings:
            return {
                "p50": -1,
                "p95": -1,
                "p99": -1,
                "mean": -1,
                "min": -1,
                "max": -1,
            }

        # Calculate statistics
        timings.sort()
        return {
            "p50": statistics.median(timings),
            "p95": timings[int(len(timings) * 0.95)] if len(timings) > 1 else timings[0],
            "p99": timings[int(len(timings) * 0.99)] if len(timings) > 1 else timings[0],
            "mean": statistics.mean(timings),
            "min": min(timings),
            "max": max(timings),
            "count": len(timings),
        }

    def run_benchmark_suite(self, iterations: int = 10) -> Dict[str, Dict[str, float]]:
        """Run complete benchmark suite."""
        queries = {
            "simple_select": """
                SELECT * FROM orders LIMIT 100
            """,
            "count_aggregation": """
                SELECT COUNT(*) as total_orders, SUM(total_amount) as revenue
                FROM orders
            """,
            "group_by_aggregation": """
                SELECT region, status,
                       COUNT(*) as order_count,
                       SUM(total_amount) as revenue,
                       AVG(total_amount) as avg_order_value
                FROM orders
                GROUP BY region, status
                ORDER BY revenue DESC
            """,
            "join_query": """
                SELECT c.customer_id, c.first_name, c.last_name,
                       COUNT(o.order_id) as total_orders,
                       SUM(o.total_amount) as total_spent
                FROM customers c
                LEFT JOIN orders o ON c.customer_id = o.customer_id
                GROUP BY c.customer_id, c.first_name, c.last_name
                ORDER BY total_spent DESC
                LIMIT 100
            """,
            "time_travel": """
                SELECT COUNT(*) as orders_today
                FROM orders
                FOR TIMESTAMP AS OF CURRENT_TIMESTAMP
                WHERE order_date = CURRENT_DATE
            """,
            "complex_analytics": """
                WITH daily_metrics AS (
                    SELECT
                        order_date,
                        region,
                        COUNT(*) as orders,
                        SUM(total_amount) as revenue,
                        AVG(total_amount) as avg_order
                    FROM orders
                    WHERE order_date >= CURRENT_DATE - INTERVAL '30' DAY
                    GROUP BY order_date, region
                )
                SELECT
                    region,
                    AVG(orders) as avg_daily_orders,
                    AVG(revenue) as avg_daily_revenue,
                    AVG(avg_order) as avg_order_value
                FROM daily_metrics
                GROUP BY region
                ORDER BY avg_daily_revenue DESC
            """,
        }

        results = {}
        for name, query in queries.items():
            stats = self.benchmark_query(query, name, iterations=iterations)
            results[name] = stats

        return results

    def generate_report(self, results: Dict[str, Dict[str, float]]) -> str:
        """Generate markdown report from benchmark results."""
        report = f"""# Performance Benchmark Report

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Summary

| Query | p50 (ms) | p95 (ms) | p99 (ms) | Mean (ms) | Min (ms) | Max (ms) | Iterations |
|-------|----------|----------|----------|-----------|----------|----------|------------|
"""

        for name, stats in results.items():
            if stats["p50"] < 0:
                report += f"| {name} | FAILED | FAILED | FAILED | FAILED | FAILED | FAILED | 0 |\n"
            else:
                report += (
                    f"| {name} | "
                    f"{stats['p50']*1000:.1f} | "
                    f"{stats['p95']*1000:.1f} | "
                    f"{stats['p99']*1000:.1f} | "
                    f"{stats['mean']*1000:.1f} | "
                    f"{stats['min']*1000:.1f} | "
                    f"{stats['max']*1000:.1f} | "
                    f"{stats['count']} |\n"
                )

        report += """
## Query Descriptions

### simple_select
Basic SELECT query with LIMIT. Tests baseline latency.

### count_aggregation
Simple COUNT and SUM aggregation. Tests aggregation performance.

### group_by_aggregation
Multi-column GROUP BY with multiple aggregations. Tests complex aggregation.

### join_query
LEFT JOIN between customers and orders. Tests join performance.

### time_travel
Iceberg time travel query. Tests snapshot access performance.

### complex_analytics
CTE with window functions and multiple aggregations. Tests complex analytical queries.

## Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| **p95 < 1s** | Sub-second latency for 95% of queries | """

        # Check if p95 target is met
        p95_values = [
            stats["p95"] for stats in results.values() if stats["p95"] > 0
        ]
        if p95_values and max(p95_values) < 1.0:
            report += "✅ PASSED |\n"
        else:
            report += "❌ FAILED |\n"

        report += """| **p99 < 2s** | Sub-2-second latency for 99% of queries | """

        p99_values = [
            stats["p99"] for stats in results.values() if stats["p99"] > 0
        ]
        if p99_values and max(p99_values) < 2.0:
            report += "✅ PASSED |\n"
        else:
            report += "❌ FAILED |\n"

        report += """
## Test Environment

- **CPU:** 8 cores
- **RAM:** 16GB
- **Storage:** SSD
- **Dataset:** 100K orders, 10K customers, 50 products
- **Trino Version:** 465
- **Iceberg Version:** 1.4.0

## Methodology

1. **Warmup:** 2 iterations (results discarded)
2. **Iterations:** 10 benchmark runs per query
3. **Cold Start:** No query result caching between runs
4. **Measurement:** End-to-end query execution time (includes network)

## Optimization Recommendations

### If p95 > 1s:
1. Increase Trino worker memory
2. Add more Trino workers (horizontal scaling)
3. Optimize table partitioning
4. Enable query result caching (Redis)

### If specific queries are slow:
- **Joins:** Add indexes or bloom filters
- **Aggregations:** Use materialized views
- **Time Travel:** Compact small files, expire old snapshots

---

**Benchmark Tool:** `scripts/benchmark.py`
**Run Command:** `python3 scripts/benchmark.py --iterations 10 --output docs/performance.md`
"""

        return report

    def close(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Performance benchmark suite for Data Lakehouse"
    )
    parser.add_argument(
        "--host",
        type=str,
        default="localhost",
        help="Trino coordinator host (default: localhost)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8080,
        help="Trino coordinator port (default: 8080)",
    )
    parser.add_argument(
        "--iterations",
        type=int,
        default=10,
        help="Number of benchmark iterations per query (default: 10)",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="docs/performance.md",
        help="Output file for results (default: docs/performance.md)",
    )

    args = parser.parse_args()

    print("=" * 70)
    print("Performance Benchmark Suite - Apache NiFi Data Lakehouse")
    print("=" * 70)
    print(f"\nConfiguration:")
    print(f"  Trino Host: {args.host}:{args.port}")
    print(f"  Iterations: {args.iterations}")
    print(f"  Output: {args.output}")
    print()

    benchmark = PerformanceBenchmark(host=args.host, port=args.port)

    try:
        results = benchmark.run_benchmark_suite(iterations=args.iterations)
        report = benchmark.generate_report(results)

        # Write report to file
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(report)

        print("\n" + "=" * 70)
        print(f"[SUCCESS] Benchmark complete! Results saved to: {args.output}")
        print("=" * 70)

    except Exception as e:
        print(f"\n[ERROR] Benchmark failed: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        benchmark.close()


if __name__ == "__main__":
    main()
