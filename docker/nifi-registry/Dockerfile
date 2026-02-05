# Apache NiFi Registry with PostgreSQL Driver and Git Integration
FROM apache/nifi-registry:2.7.2

# Switch to root to install packages
USER root

# Install Git for flow versioning
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add PostgreSQL JDBC driver for database persistence
# Place in /lib/ directory to ensure it's in the classpath
RUN curl -L -o /opt/nifi-registry/nifi-registry-current/lib/postgresql-42.7.1.jar \
    https://jdbc.postgresql.org/download/postgresql-42.7.1.jar && \
    chown nifi:nifi /opt/nifi-registry/nifi-registry-current/lib/postgresql-42.7.1.jar && \
    chmod 644 /opt/nifi-registry/nifi-registry-current/lib/postgresql-42.7.1.jar

# Create flow storage directory and initialize Git repository
RUN mkdir -p /opt/nifi-registry/flow-storage && \
    chown -R nifi:nifi /opt/nifi-registry/flow-storage && \
    cd /opt/nifi-registry/flow-storage && \
    git init && \
    git config user.name "NiFi Registry" && \
    git config user.email "nifi-registry@localhost" && \
    echo "# NiFi Registry Flow Storage" > README.md && \
    git add README.md && \
    git commit -m "Initial commit"

# Switch back to nifi user
USER nifi

# Metadata
LABEL maintainer="Data Engineering Portfolio"
LABEL description="NiFi Registry with PostgreSQL driver and Git integration"
LABEL version="2.7.2-postgresql-git"
