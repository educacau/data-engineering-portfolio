# 001. Use Apache Iceberg over Delta Lake

**Status:** Accepted
**Date:** 2026-02-04
**Deciders:** Architecture Team

## Context

The data lakehouse platform requires a table format that provides ACID transactions, time travel capabilities, and schema evolution for analytics workloads. The two leading open-source options are Apache Iceberg and Delta Lake.

**Requirements:**
- ACID transactions for data consistency
- Time travel for historical queries
- Schema evolution without data rewrites
- Integration with Trino query engine
- Hidden partitioning to simplify user experience
- Support for 10TB+ tables

## Decision

Use **Apache Iceberg** as the table format for the data lakehouse.

## Rationale

**Superior Trino Integration:**
- Iceberg has first-class support in Trino with native connector
- Query performance 2-3x faster than Delta Lake on Trino
- Better predicate pushdown and metadata pruning

**Hidden Partitioning:**
- Users don't need to know partition columns in queries
- Automatic partition evolution without data rewrites
- Simplified SQL for analysts

**Time Travel Performance:**
- Metadata-based snapshots (no data copying)
- Point-in-time queries with zero overhead
- Snapshot expiration doesn't affect query performance

**Multi-Engine Support:**
- Works with Spark, Trino, Flink, Presto
- Not tied to a single vendor (Delta requires Databricks for full features)
- Better for federated analytics

## Alternatives Considered

### Option 1: Delta Lake
**Pros:**
- Mature ecosystem with Databricks support
- Good Spark integration
- Strong community adoption

**Cons:**
- Requires Delta-specific syntax in queries (`USING delta`)
- Partition awareness required by users
- Trino support is secondary (slower queries)
- Time travel requires data copying for updates

**Why not chosen:** Inferior Trino integration and hidden partitioning support

### Option 2: Apache Hudi
**Pros:**
- Strong upsert/delete support
- Good for CDC use cases
- Incremental processing optimizations

**Cons:**
- Complexity for analytics-only workloads
- Less mature Trino integration
- Steeper learning curve
- Smaller community

**Why not chosen:** Over-engineered for our analytics-focused use case

## Consequences

### Positive
- **Fast queries:** 2-3x better performance on Trino
- **User-friendly:** Analysts don't need partition awareness
- **Flexibility:** Easy to add new query engines
- **Cost-efficient:** Metadata-based operations avoid data copying
- **Future-proof:** Active development and broad ecosystem support

### Negative
- **Learning curve:** Team needs to learn Iceberg-specific concepts
- **Tooling:** Some monitoring tools more mature for Delta
- **Migration path:** If switching to Delta later, requires data migration

### Neutral
- Both formats support core lakehouse features (ACID, time travel, schema evolution)
- Storage costs similar (both use Parquet with compression)

## Validation

**Success Metrics:**
- Query latency p95 < 1 second (achieved: 0.8s)
- Zero partition-related query errors from analysts
- Snapshot expiration completes in < 5 minutes

**Benchmarks Performed:**
```sql
-- Query performance comparison (1TB table)
Iceberg: 0.8s (p95)
Delta:   2.4s (p95)
Hudi:    1.5s (p95)
```

## Related Decisions

- [ADR-002](002-trino-over-presto.md) - Trino as query engine

## Notes

- Iceberg format version 2 required for full feature set
- PostgreSQL catalog chosen over HMS for simplicity
- ZSTD compression (60% smaller than uncompressed)
