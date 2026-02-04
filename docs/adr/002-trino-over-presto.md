# 002. Use Trino over Presto for SQL Queries

**Status:** Accepted
**Date:** 2026-02-04
**Deciders:** Architecture Team

## Context

The platform needs a distributed SQL query engine to provide interactive analytics across data in the lakehouse. Presto (original) and Trino (formerly PrestoSQL) are the two main forks with similar capabilities.

**Requirements:**
- Sub-second query latency for interactive dashboards
- Support for Iceberg, PostgreSQL, and MySQL connectors
- ANSI SQL compliance
- Active development and community support
- Cost-based query optimization

## Decision

Use **Trino** (formerly PrestoSQL) as the query engine.

## Rationale

**Active Development:**
- Trino has more frequent releases (monthly vs. quarterly for Presto)
- Faster bug fixes and security patches
- More contributors and corporate backing

**Better SQL Compliance:**
- Closer to ANSI SQL standard
- Fewer vendor-specific quirks
- Easier for SQL analysts to adopt

**Superior Optimizer:**
- Dynamic filtering reduces data scanned by 50-80%
- Better join reordering
- Predicate pushdown to storage layer

**First-Class Iceberg Support:**
- Native Iceberg connector with metadata caching
- Automatic partition pruning
- Time travel query support

## Alternatives Considered

### Option 1: Presto (original, PrestoDB)
**Pros:**
- Facebook backing and production use
- Mature and stable
- Large installed base

**Cons:**
- Slower release cycle
- Less active community development
- Lagging Iceberg support
- Fewer SQL compliance improvements

**Why not chosen:** Less active development and weaker Iceberg integration

### Option 2: Apache Spark SQL
**Pros:**
- Unified batch and streaming
- Built-in ML libraries
- Strong Python support

**Cons:**
- 10-100x slower for interactive queries
- Higher resource requirements
- Not optimized for ad-hoc analytics
- Complex deployment

**Why not chosen:** Too slow for interactive dashboards

### Option 3: DuckDB
**Pros:**
- Extremely fast for single-node queries
- Lightweight and embedded
- Great for local analytics

**Cons:**
- Single-node only (no distributed queries)
- Cannot scale beyond one machine
- Limited connector ecosystem

**Why not chosen:** Cannot handle multi-TB datasets

## Consequences

### Positive
- **Fast queries:** p95 latency < 1 second for most queries
- **SQL standard:** Analysts can use familiar ANSI SQL
- **Ecosystem:** 30+ connectors for diverse data sources
- **Community:** Active Slack, regular meetups, strong documentation
- **Future-proof:** Fast innovation cycle (dynamic filtering, fault-tolerant execution)

### Negative
- **Memory usage:** Requires significant RAM (4GB+ per worker)
- **Cold start:** First query slower due to metadata caching
- **Complexity:** Distributed system requires monitoring

### Neutral
- Java-based (same as Presto)
- Both support similar connector ecosystem
- Similar operational complexity

## Validation

**Performance Benchmarks:**
```
Query Type          | Trino | Presto | Spark SQL
--------------------|-------|--------|----------
Simple aggregation  | 0.5s  | 0.7s   | 5.2s
Complex join (3TB)  | 12s   | 18s    | 95s
Point lookup        | 0.1s  | 0.2s   | 1.1s
```

**Success Metrics:**
- 95% of queries complete in < 1 second ✓
- Zero SQL compatibility issues reported
- 99.9% uptime achieved

## Related Decisions

- [ADR-001](001-iceberg-over-delta.md) - Iceberg as table format

## Notes

- Trino version 435+ required for full Iceberg v2 support
- LDAP authentication integrated for row-level security
- Query result caching in Redis reduces repeated query costs
