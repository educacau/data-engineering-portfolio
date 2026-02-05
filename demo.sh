#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Apache NiFi Data Lakehouse - Demo Launcher
# =============================================================================
# One-command demonstration with:
# - Prerequisite validation
# - Synthetic data generation
# - Docker Compose orchestration
# - Health check monitoring
# - Service URL display
#
# Target startup time: < 5 minutes
# Memory footprint: < 4GB
#
# Usage: ./demo.sh
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REQUIRED_DOCKER_VERSION="20.10"
REQUIRED_MEMORY_GB=4
HEALTH_CHECK_TIMEOUT=300
DATA_VOLUME=100000

# Exit codes
EXIT_PREREQ_FAILED=1
EXIT_DATA_GEN_FAILED=2
EXIT_STARTUP_FAILED=3
EXIT_HEALTH_TIMEOUT=4

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║        Apache NiFi Data Lakehouse - Demo Mode                    ║
║                                                                  ║
║   Production-grade data platform with < 5min startup             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed"
        return 1
    fi
    return 0
}

version_gte() {
    # Compare versions: $1 >= $2
    printf '%s\n%s' "$2" "$1" | sort -V -C
}

# =============================================================================
# Prerequisite Validation
# =============================================================================

validate_prerequisites() {
    log_info "Validating prerequisites..."
    local failed=0

    # Check Docker
    if ! check_command docker; then
        log_error "Docker is required. Install from https://docs.docker.com/get-docker/"
        failed=1
    else
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0")
        if version_gte "$DOCKER_VERSION" "$REQUIRED_DOCKER_VERSION"; then
            log_success "Docker $DOCKER_VERSION detected"
        else
            log_error "Docker $REQUIRED_DOCKER_VERSION+ required (found $DOCKER_VERSION)"
            failed=1
        fi
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose V2 required. Update Docker Desktop or install docker-compose-plugin"
        failed=1
    else
        log_success "Docker Compose V2 detected"
    fi

    # Check Python for data generation
    if ! check_command python3 && ! check_command python; then
        log_error "Python 3.11+ required for data generation"
        failed=1
    else
        PYTHON_CMD=$(command -v python3 || command -v python)
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
        log_success "Python $PYTHON_VERSION detected"
    fi

    # Check Docker memory allocation
    if command -v docker &> /dev/null; then
        DOCKER_MEMORY=$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo "0")
        DOCKER_MEMORY_GB=$((DOCKER_MEMORY / 1024 / 1024 / 1024))

        if [ "$DOCKER_MEMORY_GB" -ge "$REQUIRED_MEMORY_GB" ]; then
            log_success "Docker memory: ${DOCKER_MEMORY_GB}GB (minimum: ${REQUIRED_MEMORY_GB}GB)"
        else
            log_warning "Docker memory: ${DOCKER_MEMORY_GB}GB (recommended: ${REQUIRED_MEMORY_GB}GB+)"
            log_warning "Increase Docker memory in Docker Desktop > Settings > Resources"
        fi
    fi

    # Check port availability
    log_info "Checking port availability..."
    local ports=(8443 18080 8088 8888 8080 9000 9001 9090 3000)
    local ports_in_use=()

    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -an 2>/dev/null | grep -q ":$port.*LISTEN"; then
            ports_in_use+=($port)
        fi
    done

    if [ ${#ports_in_use[@]} -gt 0 ]; then
        log_warning "Ports in use: ${ports_in_use[*]}"
        log_warning "Stop conflicting services or modify docker/docker-compose.yml"
    else
        log_success "All required ports available"
    fi

    if [ $failed -eq 1 ]; then
        log_error "Prerequisites validation failed"
        return $EXIT_PREREQ_FAILED
    fi

    log_success "Prerequisites validated successfully"
    return 0
}

# =============================================================================
# Data Generation
# =============================================================================

generate_data() {
    log_info "Generating synthetic data ($DATA_VOLUME orders)..."

    cd demo/data || {
        log_error "demo/data directory not found"
        return $EXIT_DATA_GEN_FAILED
    }

    # Check if data already exists
    if [ -f "output/orders.csv" ] && [ -f "output/customers.csv" ] && [ -f "output/products.csv" ]; then
        log_warning "Data files already exist in demo/data/output/"
        read -p "Regenerate data? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Using existing data files"
            cd ../..
            return 0
        fi
    fi

    # Install dependencies if needed
    if ! $PYTHON_CMD -c "import faker" &>/dev/null; then
        log_info "Installing Python dependencies..."
        $PYTHON_CMD -m pip install -q -r requirements.txt || {
            log_error "Failed to install Python dependencies"
            return $EXIT_DATA_GEN_FAILED
        }
    fi

    # Generate data
    local start_time=$(date +%s)

    $PYTHON_CMD generate.py --volume "$DATA_VOLUME" --format csv --output output || {
        log_error "Data generation failed"
        cd ../..
        return $EXIT_DATA_GEN_FAILED
    }

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "Data generated in ${duration}s"
    cd ../..
    return 0
}

# =============================================================================
# Docker Compose Management
# =============================================================================

start_services() {
    log_info "Starting Docker Compose services..."

    cd docker || {
        log_error "docker directory not found"
        return $EXIT_STARTUP_FAILED
    }

    # Check if .env exists
    if [ ! -f .env ]; then
        log_warning ".env file not found, copying from .env.example"
        cp .env.example .env
        log_warning "Review docker/.env and update passwords before production use"
    fi

    # Start services
    local start_time=$(date +%s)

    docker compose up -d || {
        log_error "Failed to start Docker Compose services"
        cd ..
        return $EXIT_STARTUP_FAILED
    }

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "Services started in ${duration}s"
    cd ..
    return 0
}

# =============================================================================
# Health Checks
# =============================================================================

wait_for_health() {
    log_info "Waiting for services to become healthy (timeout: ${HEALTH_CHECK_TIMEOUT}s)..."

    local services=(
        "https://localhost:8443/nifi/|NiFi"
        "http://localhost:18080/nifi-registry|NiFi Registry"
        "http://localhost:8088/health|Superset"
        "http://localhost:8080/v1/info|Trino"
        "http://localhost:9000/minio/health/live|MinIO"
    )

    local start_time=$(date +%s)
    local all_healthy=false

    while [ $(($(date +%s) - start_time)) -lt $HEALTH_CHECK_TIMEOUT ]; do
        all_healthy=true

        for service_info in "${services[@]}"; do
            IFS='|' read -r url name <<< "$service_info"

            if curl -sf -o /dev/null --max-time 5 "$url" 2>/dev/null || \
               curl -sf -o /dev/null --max-time 5 -k "$url" 2>/dev/null; then
                echo -ne "\r${GREEN}✓${NC} $name is healthy    "
            else
                echo -ne "\r${YELLOW}⏳${NC} Waiting for $name..."
                all_healthy=false
                break
            fi
        done

        if $all_healthy; then
            echo ""
            log_success "All services are healthy"
            return 0
        fi

        sleep 5
    done

    log_error "Health check timeout after ${HEALTH_CHECK_TIMEOUT}s"
    log_error "Check logs with: docker compose -f docker/docker-compose.yml logs"
    return $EXIT_HEALTH_TIMEOUT
}

# =============================================================================
# Service URLs Display
# =============================================================================

display_urls() {
    cat << "EOF"

╔══════════════════════════════════════════════════════════════════╗
║                   Demo Started Successfully!                     ║
╚══════════════════════════════════════════════════════════════════╝

Access the following services:

🔧 Data Ingestion:
   Apache NiFi       https://localhost:8443/nifi
                     Username: nifi
                     Password: changeme123

   NiFi Registry     http://localhost:18080/nifi-registry
                     (Flow version control)

📊 Analytics:
   Apache Superset   http://localhost:8088
                     Username: admin
                     Password: admin

📓 Interactive Analysis:
   Jupyter Lab       http://localhost:8888
                     Token: jupyter123

🔍 SQL Query:
   Trino UI          http://localhost:8080

💾 Object Storage:
   MinIO Console     http://localhost:9001
                     Username: minio
                     Password: minio123

📈 Monitoring:
   Grafana           http://localhost:3000
                     Username: admin
                     Password: admin

   Prometheus        http://localhost:9090

📂 Sample Queries:
   demo/queries/*.sql

📋 Dashboards:
   demo/dashboards/*.json

🔄 NiFi Flows:
   demo/flows/*.xml

───────────────────────────────────────────────────────────────────

Quick Commands:

  # View logs
  docker compose -f docker/docker-compose.yml logs -f

  # Stop services (keep data)
  docker compose -f docker/docker-compose.yml down

  # Stop and remove data
  docker compose -f docker/docker-compose.yml down -v

  # Restart specific service
  docker compose -f docker/docker-compose.yml restart nifi-1

  # Run sample query
  docker exec trino trino --execute "SELECT COUNT(*) FROM iceberg.db.orders"

───────────────────────────────────────────────────────────────────

Next Steps:

  1. Open NiFi UI and import flows from demo/flows/
  2. Open Superset and import dashboards from demo/dashboards/
  3. Explore data with sample queries in demo/queries/
  4. Monitor performance in Grafana

───────────────────────────────────────────────────────────────────
EOF
}

# =============================================================================
# Cleanup
# =============================================================================

cleanup_on_error() {
    log_error "Demo startup failed. Cleaning up..."
    docker compose -f docker/docker-compose.yml down 2>/dev/null || true
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_banner
    echo ""

    local start_time=$(date +%s)

    # Trap errors for cleanup
    trap cleanup_on_error ERR

    # Step 1: Validate prerequisites
    validate_prerequisites || exit $EXIT_PREREQ_FAILED

    echo ""

    # Step 2: Generate data
    generate_data || exit $EXIT_DATA_GEN_FAILED

    echo ""

    # Step 3: Start services
    start_services || exit $EXIT_STARTUP_FAILED

    echo ""

    # Step 4: Wait for health
    wait_for_health || exit $EXIT_HEALTH_TIMEOUT

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo ""
    log_success "Total startup time: ${total_duration}s (target: < 300s)"

    # Step 5: Display URLs
    display_urls

    # Success
    return 0
}

# Run main function
main "$@"
