#!/bin/bash
#
# Import NiFi Flows to Registry
#
# This script imports all XML flow templates into NiFi Registry
# for use with NiFi 2.7.2+ (which no longer supports direct template import)
#
# Usage:
#   ./scripts/import-flows.sh
#
# Prerequisites:
#   - Python 3.x
#   - pip install requests
#   - NiFi Registry running on localhost:18080
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  NiFi Registry Flow Importer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}[ERROR] Python 3 is required${NC}"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Python 3 found: $(python3 --version)"

# Check/Install requests library
echo ""
echo -e "${YELLOW}Checking Python dependencies...${NC}"

if ! python3 -c "import requests" 2>/dev/null; then
    echo -e "${YELLOW}Installing requests library...${NC}"
    pip3 install requests
fi

echo -e "${GREEN}[OK]${NC} Dependencies ready"

# Check Registry
echo ""
echo -e "${YELLOW}Checking NiFi Registry...${NC}"

if ! curl -f -s http://localhost:18080/nifi-registry > /dev/null 2>&1; then
    echo -e "${RED}[ERROR] NiFi Registry is not accessible${NC}"
    echo ""
    echo -e "${YELLOW}Please start NiFi Registry:${NC}"
    echo "  docker ps | grep nifi-registry"
    echo "  docker logs nifi-registry"
    echo ""
    echo -e "${YELLOW}Or start the full stack:${NC}"
    echo "  docker compose up -d"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK]${NC} NiFi Registry is accessible"

# Run import
echo ""
echo -e "${YELLOW}Starting import...${NC}"
echo ""

python3 scripts/import-flows-to-registry.py

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Import Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Open NiFi: ${BLUE}https://localhost:8443/nifi${NC}"
    echo "  2. Add Registry Client:"
    echo "     Menu (☰) → Controller Settings → Registry Clients"
    echo "     Name: Local Registry"
    echo "     URL: ${BLUE}http://nifi-registry:18080${NC}"
    echo "  3. Import flows from Registry:"
    echo "     Right-click canvas → Version → Import from Registry"
    echo "     Select: demo-flows bucket → Choose flow → Import"
    echo ""
else
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Import Failed${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  - Check Registry logs: docker logs nifi-registry"
    echo "  - Verify Registry is running: docker ps | grep registry"
    echo "  - Check connectivity: curl http://localhost:18080/nifi-registry"
    echo ""
    exit $exit_code
fi
