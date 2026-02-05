# Apache NiFi Registry with PostgreSQL Driver
FROM apache/nifi-registry:2.7.2

# Add PostgreSQL JDBC driver for database persistence
# Place in /lib/ directory to ensure it's in the classpath
RUN curl -L -o /opt/nifi-registry/nifi-registry-current/lib/postgresql-42.7.1.jar \
    https://jdbc.postgresql.org/download/postgresql-42.7.1.jar && \
    chown nifi:nifi /opt/nifi-registry/nifi-registry-current/lib/postgresql-42.7.1.jar && \
    chmod 644 /opt/nifi-registry/nifi-registry-current/lib/postgresql-42.7.1.jar

# Metadata
LABEL maintainer="Data Engineering Portfolio"
LABEL description="NiFi Registry with PostgreSQL driver for flow versioning"
LABEL version="2.7.2-postgresql"
