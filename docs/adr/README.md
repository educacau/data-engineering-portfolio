# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) documenting significant architectural choices made in the Data Lakehouse platform.

## What is an ADR?

An Architecture Decision Record captures an important architectural decision along with its context and consequences. This helps:
- Preserve reasoning behind technical choices
- Onboard new team members faster
- Revisit decisions when circumstances change
- Avoid repeating past discussions

## ADR Format

Each ADR follows this structure:
1. **Status** - Proposed, Accepted, Deprecated, Superseded
2. **Context** - The issue motivating this decision
3. **Decision** - The change being proposed or agreed upon
4. **Consequences** - The resulting context after applying the decision

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](001-iceberg-over-delta.md) | Use Apache Iceberg over Delta Lake | Accepted | 2026-02-04 |
| [002](002-trino-over-presto.md) | Use Trino over Presto for SQL queries | Accepted | 2026-02-04 |
| [003](003-kafka-security.md) | Implement SASL_SSL for Kafka security | Accepted | 2026-02-04 |
| [004](004-docker-compose-over-k8s.md) | Use Docker Compose over Kubernetes for demo | Accepted | 2026-02-04 |
| [005](005-nifi-cluster-sizing.md) | Deploy 3-node NiFi cluster | Accepted | 2026-02-04 |

## References

- [Michael Nygard's ADR Template](https://github.com/joelparkerhenderson/architecture-decision-record)
- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
