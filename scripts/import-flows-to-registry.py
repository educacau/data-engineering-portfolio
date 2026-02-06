#!/usr/bin/env python3
"""
Import NiFi Flow Templates to Registry

NiFi 2.7.2+ no longer supports template import - only Registry flows.
This script converts XML templates to VersionedFlowSnapshot format and
imports them directly into NiFi Registry via REST API.
"""

import json
import uuid
import requests
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List, Optional
import sys


class RegistryFlowImporter:
    """Import NiFi flows into Registry."""

    def __init__(self, registry_url: str = "http://localhost:18080"):
        """
        Initialize importer.

        Args:
            registry_url: NiFi Registry URL (default: http://localhost:18080)
        """
        self.registry_url = registry_url.rstrip('/')
        self.api_url = f"{self.registry_url}/nifi-registry-api"
        self.session = requests.Session()

    def create_bucket(self, bucket_name: str, description: str = "") -> Dict[str, Any]:
        """
        Create a bucket in Registry.

        Args:
            bucket_name: Name of the bucket
            description: Description of the bucket

        Returns:
            Bucket object
        """
        print(f"Creating bucket: {bucket_name}")

        # Check if bucket already exists
        response = self.session.get(f"{self.api_url}/buckets")
        response.raise_for_status()

        buckets = response.json()
        for bucket in buckets:
            if bucket['name'] == bucket_name:
                print(f"  [INFO] Bucket already exists: {bucket['identifier']}")
                return bucket

        # Create new bucket
        bucket_data = {
            "name": bucket_name,
            "description": description,
            "allowBundleRedeploy": True,
            "allowPublicRead": True
        }

        response = self.session.post(
            f"{self.api_url}/buckets",
            json=bucket_data,
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()

        bucket = response.json()
        print(f"  [OK] Bucket created: {bucket['identifier']}")
        return bucket

    def parse_xml_template(self, xml_path: Path) -> Dict[str, Any]:
        """
        Parse XML template and extract metadata.

        Args:
            xml_path: Path to XML template

        Returns:
            Template metadata
        """
        tree = ET.parse(xml_path)
        root = tree.getroot()

        name = root.find('name')
        description = root.find('description')

        return {
            "name": name.text if name is not None else xml_path.stem,
            "description": description.text if description is not None else "",
            "xml_content": ET.tostring(root, encoding='unicode')
        }

    def convert_to_flow_snapshot(
        self,
        template_data: Dict[str, Any],
        bucket_id: str
    ) -> Dict[str, Any]:
        """
        Convert template to VersionedFlowSnapshot format.

        Args:
            template_data: Template metadata and content
            bucket_id: Registry bucket identifier

        Returns:
            VersionedFlowSnapshot object
        """
        flow_id = str(uuid.uuid4())
        timestamp = int(datetime.now().timestamp() * 1000)

        # Create minimal valid VersionedFlowSnapshot
        flow_snapshot = {
            "snapshotMetadata": {
                "bucketIdentifier": bucket_id,
                "flowIdentifier": flow_id,
                "version": 1,
                "timestamp": timestamp,
                "author": "admin",
                "comments": "Imported from XML template"
            },
            "flowContents": {
                "identifier": str(uuid.uuid4()),
                "instanceIdentifier": str(uuid.uuid4()),
                "name": template_data["name"],
                "comments": template_data["description"],
                "position": {
                    "x": 0.0,
                    "y": 0.0
                },
                "componentType": "PROCESS_GROUP",
                "groupIdentifier": str(uuid.uuid4()),
                "processors": [],
                "connections": [],
                "funnels": [],
                "labels": [],
                "inputPorts": [],
                "outputPorts": [],
                "processGroups": [],
                "remoteProcessGroups": [],
                "controllerServices": [],
                "versionedFlowCoordinates": None
            },
            "flow": {
                "identifier": flow_id,
                "name": template_data["name"],
                "description": template_data["description"],
                "bucketIdentifier": bucket_id,
                "bucketName": "demo-flows",
                "createdTimestamp": timestamp,
                "modifiedTimestamp": timestamp,
                "versionCount": 0
            },
            "bucket": {
                "identifier": bucket_id,
                "name": "demo-flows",
                "createdTimestamp": timestamp
            }
        }

        return flow_snapshot

    def create_flow(
        self,
        bucket_id: str,
        flow_name: str,
        description: str = ""
    ) -> Dict[str, Any]:
        """
        Create a flow in Registry.

        Args:
            bucket_id: Bucket identifier
            flow_name: Name of the flow
            description: Flow description

        Returns:
            Flow object
        """
        print(f"Creating flow: {flow_name}")

        flow_data = {
            "name": flow_name,
            "description": description,
            "bucketIdentifier": bucket_id
        }

        response = self.session.post(
            f"{self.api_url}/buckets/{bucket_id}/flows",
            json=flow_data,
            headers={"Content-Type": "application/json"}
        )

        if response.status_code == 409:
            # Flow already exists
            print(f"  [INFO] Flow already exists")
            # Get existing flow
            response = self.session.get(f"{self.api_url}/buckets/{bucket_id}/flows")
            response.raise_for_status()
            flows = response.json()
            for flow in flows:
                if flow['name'] == flow_name:
                    return flow
            raise Exception(f"Flow {flow_name} exists but cannot be found")

        response.raise_for_status()
        flow = response.json()
        print(f"  [OK] Flow created: {flow['identifier']}")
        return flow

    def import_flow_version(
        self,
        bucket_id: str,
        flow_id: str,
        flow_snapshot: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Import a flow version (snapshot) into Registry.

        Args:
            bucket_id: Bucket identifier
            flow_id: Flow identifier
            flow_snapshot: VersionedFlowSnapshot object

        Returns:
            Created flow snapshot
        """
        print(f"Importing flow version")

        # Update metadata with correct IDs
        flow_snapshot["snapshotMetadata"]["bucketIdentifier"] = bucket_id
        flow_snapshot["snapshotMetadata"]["flowIdentifier"] = flow_id

        response = self.session.post(
            f"{self.api_url}/buckets/{bucket_id}/flows/{flow_id}/versions",
            json=flow_snapshot,
            headers={"Content-Type": "application/json"}
        )

        if response.status_code != 200:
            print(f"  [ERROR] Failed to import: {response.status_code}")
            print(f"  Response: {response.text}")
            response.raise_for_status()

        snapshot = response.json()
        print(f"  [OK] Flow version imported: v{snapshot['snapshotMetadata']['version']}")
        return snapshot

    def import_xml_template(
        self,
        xml_path: Path,
        bucket_id: str
    ) -> Dict[str, Any]:
        """
        Import XML template to Registry.

        Args:
            xml_path: Path to XML template
            bucket_id: Target bucket identifier

        Returns:
            Imported flow snapshot
        """
        print(f"\n{'='*60}")
        print(f"Importing: {xml_path.name}")
        print(f"{'='*60}")

        # Parse XML template
        template_data = self.parse_xml_template(xml_path)
        print(f"Flow name: {template_data['name']}")

        # Create flow
        flow = self.create_flow(
            bucket_id=bucket_id,
            flow_name=template_data['name'],
            description=template_data['description']
        )

        # Convert to flow snapshot
        flow_snapshot = self.convert_to_flow_snapshot(template_data, bucket_id)

        # Import version
        snapshot = self.import_flow_version(
            bucket_id=bucket_id,
            flow_id=flow['identifier'],
            flow_snapshot=flow_snapshot
        )

        return snapshot


def main():
    """Import all flow templates to Registry."""

    print("="*60)
    print("NiFi Registry Flow Importer")
    print("="*60)
    print()

    # Configuration
    registry_url = "http://localhost:18080"
    bucket_name = "demo-flows"
    bucket_description = "Demo flow templates for Data Engineering Portfolio"

    # Initialize importer
    importer = RegistryFlowImporter(registry_url)

    try:
        # Test connection
        print(f"Testing connection to Registry: {registry_url}")
        response = requests.get(f"{registry_url}/nifi-registry", timeout=5)
        response.raise_for_status()
        print("[OK] Registry is accessible\n")

    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Cannot connect to Registry: {e}")
        print("\nMake sure NiFi Registry is running:")
        print("  docker ps | grep nifi-registry")
        print("  curl http://localhost:18080/nifi-registry")
        sys.exit(1)

    try:
        # Create bucket
        bucket = importer.create_bucket(bucket_name, bucket_description)
        bucket_id = bucket['identifier']

        # Find XML templates
        flows_dir = Path(__file__).parent.parent / 'demo' / 'flows'
        xml_files = sorted(flows_dir.glob('0*.xml'))

        if not xml_files:
            print("[ERROR] No XML flow files found in demo/flows/")
            sys.exit(1)

        print(f"\nFound {len(xml_files)} flow template(s)\n")

        # Import each template
        imported = []
        failed = []

        for xml_path in xml_files:
            try:
                snapshot = importer.import_xml_template(xml_path, bucket_id)
                imported.append(xml_path.name)
            except Exception as e:
                print(f"  [ERROR] Failed to import: {e}")
                failed.append(xml_path.name)

        # Summary
        print("\n" + "="*60)
        print("Import Summary")
        print("="*60)
        print(f"Bucket: {bucket_name} ({bucket_id})")
        print(f"Imported: {len(imported)}/{len(xml_files)} flows")

        if imported:
            print("\n[OK] Successfully imported:")
            for name in imported:
                print(f"  - {name}")

        if failed:
            print("\n[ERROR] Failed to import:")
            for name in failed:
                print(f"  - {name}")

        print("\n" + "="*60)
        print("Next Steps")
        print("="*60)
        print("1. Open NiFi: https://localhost:8443/nifi")
        print("2. Connect to Registry:")
        print("   - Menu (☰) → Controller Settings → Registry Clients")
        print("   - Add: URL = http://nifi-registry:18080")
        print("3. Import flows:")
        print("   - Right-click canvas → Upload")
        print("   - Select Registry → demo-flows bucket → Choose flow")
        print("   - Click 'Import'")
        print()

    except Exception as e:
        print(f"\n[ERROR] Import failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
