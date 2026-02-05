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

# Create flow storage and extension bundle directories
# Git repository will be initialized automatically by NiFi Registry on first use
RUN mkdir -p /opt/nifi-registry/flow-storage && \
    mkdir -p /opt/nifi-registry/extension-bundles && \
    chown -R nifi:nifi /opt/nifi-registry/flow-storage && \
    chown -R nifi:nifi /opt/nifi-registry/extension-bundles

# Create providers.xml with Git+Database hybrid configuration
RUN cat > /opt/nifi-registry/nifi-registry-current/conf/providers.xml <<'PROVIDERS_EOF'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<providers>
  <flowPersistenceProvider>
    <class>org.apache.nifi.registry.provider.flow.git.GitFlowPersistenceProvider</class>
    <property name="Flow Storage Directory">/opt/nifi-registry/flow-storage</property>
    <property name="Remote To Push"></property>
    <property name="Remote Access User"></property>
    <property name="Remote Access Password"></property>
  </flowPersistenceProvider>
  <extensionBundlePersistenceProvider>
    <class>org.apache.nifi.registry.provider.extension.FileSystemBundlePersistenceProvider</class>
    <property name="Extension Bundle Storage Directory">/opt/nifi-registry/extension-bundles</property>
  </extensionBundlePersistenceProvider>
</providers>
PROVIDERS_EOF

RUN chown nifi:nifi /opt/nifi-registry/nifi-registry-current/conf/providers.xml

# Switch back to nifi user
USER nifi

# Metadata
LABEL maintainer="Data Engineering Portfolio"
LABEL description="NiFi Registry with PostgreSQL driver and Git integration"
LABEL version="2.7.2-postgresql-git"
