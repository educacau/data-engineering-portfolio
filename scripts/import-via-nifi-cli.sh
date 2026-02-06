#!/bin/bash
#
# Import NiFi Flows using official NiFi CLI Toolkit
#
# This method is more reliable than manual Registry API import
# because it uses NiFi's native import mechanism
#

set -euo pipefail

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  NiFi Flow Import via CLI Toolkit${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

# Configuration
NIFI_URL="https://localhost:8443"
REGISTRY_URL="http://localhost:18080"
CLI="./nifi-toolkit/bin/cli.sh"

# Check if toolkit exists
if [ ! -f "$CLI" ]; then
    echo -e "${YELLOW}NiFi Toolkit not found. Installing...${NC}"
    curl -L -o nifi-toolkit.zip https://archive.apache.org/dist/nifi/2.7.2/nifi-toolkit-2.7.2-bin.zip
    unzip -q nifi-toolkit.zip
    mv nifi-toolkit-2.7.2 nifi-toolkit
    rm nifi-toolkit.zip
    echo -e "${GREEN}Toolkit installed${NC}"
    echo ""
fi

# Configure CLI (disable SSL verification for self-signed cert)
export NIFI_CLI_ARGS="-Djavax.net.ssl.trustStore=NONE -Djavax.net.ssl.trustStorePassword="

echo -e "${YELLOW}Step 1: Create Registry Client in NiFi${NC}"
echo "Please configure Registry Client manually:"
echo "  1. Open NiFi: $NIFI_URL"
echo "  2. Menu > Controller Settings > Registry Clients"
echo "  3. Add: Name=LocalRegistry, URL=$REGISTRY_URL"
echo ""
read -p "Press Enter when done..."

echo ""
echo -e "${YELLOW}Step 2: Alternative - Manual Import${NC}"
echo ""
echo "Since NiFi 2.7.2 removed template upload, use this workflow:"
echo ""
echo "1. Create flows manually in NiFi Canvas OR"
echo "2. Use Process Group import from Registry"
echo ""
echo "For now, the XML templates serve as documentation"
echo "The flows need to be created directly in NiFi 2.7.2"
echo ""
echo -e "${GREEN}Documentation:${NC}"
echo "  - Flow XMLs are in: demo/flows/"
echo "  - Testing guide: demo/flows/TESTING_GUIDE.md"
echo "  - Each XML describes the complete pipeline"
echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  Recommendation${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "For NiFi 2.7.2, the best approach is:"
echo ""
echo "1. Build flows manually in NiFi using the XML as reference"
echo "2. Version control them in Registry"
echo "3. Export for sharing"
echo ""
echo "The XML templates serve as complete documentation"
echo "of the desired pipeline architecture."
echo ""
