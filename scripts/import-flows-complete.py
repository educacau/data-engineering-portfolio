#!/usr/bin/env python3
"""
Complete Flow Importer - Extracts full content from XML

This version properly extracts processors, connections, and other
components from XML templates and converts them to Registry format.
"""

import json
import uuid
import requests
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List, Optional
import sys


def generate_uuid() -> str:
    """Generate UUID string."""
    return str(uuid.uuid4())


def parse_position(elem) -> Dict[str, float]:
    """Parse position element."""
    if elem is None:
        return {"x": 0.0, "y": 0.0}
    x = elem.find('x')
    y = elem.find('y')
    return {
        "x": float(x.text) if x is not None else 0.0,
        "y": float(y.text) if y is not None else 0.0
    }


def parse_properties(config_elem) -> Dict[str, str]:
    """Parse processor properties from config."""
    properties = {}
    if config_elem is None:
        return properties

    props_elem = config_elem.find('properties')
    if props_elem is None:
        return properties

    for entry in props_elem.findall('entry'):
        key = entry.find('key')
        value = entry.find('value')
        if key is not None:
            prop_value = value.text if value is not None and value.text else ""
            properties[key.text] = prop_value

    return properties


def extract_processors(contents_elem, group_id: str) -> List[Dict[str, Any]]:
    """Extract all processors from XML contents."""
    processors = []

    if contents_elem is None:
        return processors

    for proc_elem in contents_elem.findall('.//processors'):
        proc_id = proc_elem.find('id')
        proc_name = proc_elem.find('name')
        proc_type = proc_elem.find('type')
        proc_state = proc_elem.find('state')
        position = parse_position(proc_elem.find('position'))
        config = proc_elem.find('config')

        # Extract bundle info from type
        type_str = proc_type.text if proc_type is not None else ""
        bundle_info = {
            "group": "org.apache.nifi",
            "artifact": "nifi-standard-nar",
            "version": "1.25.0"
        }

        # Parse properties
        properties = parse_properties(config)

        processor = {
            "identifier": proc_id.text if proc_id is not None else generate_uuid(),
            "name": proc_name.text if proc_name is not None else "Processor",
            "type": type_str,
            "bundle": bundle_info,
            "position": position,
            "properties": properties,
            "propertyDescriptors": {},
            "style": {},
            "schedulingPeriod": "0 sec",
            "schedulingStrategy": "TIMER_DRIVEN",
            "executionNode": "ALL",
            "penaltyDuration": "30 sec",
            "yieldDuration": "1 sec",
            "bulletinLevel": "WARN",
            "runDurationMillis": 0,
            "concurrentlySchedulableTaskCount": 1,
            "autoTerminatedRelationships": [],
            "componentType": "PROCESSOR",
            "groupIdentifier": group_id
        }

        processors.append(processor)

    return processors


def extract_connections(contents_elem, processor_ids: List[str], group_id: str) -> List[Dict[str, Any]]:
    """Extract all connections from XML contents."""
    connections = []

    if contents_elem is None:
        return connections

    for conn_elem in contents_elem.findall('.//connections'):
        conn_id = conn_elem.find('id')
        conn_name = conn_elem.find('name')

        # Extract source and destination from nested structure
        source_elem = conn_elem.find('source')
        dest_elem = conn_elem.find('destination')

        src_id = ""
        dst_id = ""

        if source_elem is not None:
            src_id_elem = source_elem.find('id')
            src_id = src_id_elem.text if src_id_elem is not None else ""

        if dest_elem is not None:
            dst_id_elem = dest_elem.find('id')
            dst_id = dst_id_elem.text if dst_id_elem is not None else ""

        # Validate that source and destination exist in processor list
        if src_id not in processor_ids:
            print(f"  [WARN] Connection source {src_id} not found in processors, skipping")
            continue
        if dst_id not in processor_ids:
            print(f"  [WARN] Connection destination {dst_id} not found in processors, skipping")
            continue

        # Extract selected relationships
        relationships = []
        selected_rels = conn_elem.find('selectedRelationships')
        if selected_rels is not None:
            for rel in selected_rels.findall('element'):
                if rel.text:
                    relationships.append(rel.text)

        connection = {
            "identifier": conn_id.text if conn_id is not None else generate_uuid(),
            "name": conn_name.text if conn_name is not None else "",
            "source": {
                "id": src_id,
                "type": "PROCESSOR",
                "groupId": group_id
            },
            "destination": {
                "id": dst_id,
                "type": "PROCESSOR",
                "groupId": group_id
            },
            "selectedRelationships": relationships,
            "backPressureObjectThreshold": 10000,
            "backPressureDataSizeThreshold": "1 GB",
            "flowFileExpiration": "0 sec",
            "prioritizers": [],
            "bends": [],
            "componentType": "CONNECTION",
            "groupIdentifier": group_id
        }

        connections.append(connection)

    return connections


def convert_xml_to_flow_snapshot(
    xml_path: Path,
    bucket_id: str
) -> Dict[str, Any]:
    """
    Convert XML template to complete VersionedFlowSnapshot.

    Args:
        xml_path: Path to XML template
        bucket_id: Registry bucket ID

    Returns:
        Complete VersionedFlowSnapshot with processors and connections
    """
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Extract metadata
    name = root.find('name')
    description = root.find('description')

    flow_name = name.text if name is not None else xml_path.stem
    flow_desc = description.text if description is not None else ""

    # Extract snippet contents
    snippet = root.find('.//snippet')
    process_group = snippet.find('.//processGroups') if snippet is not None else None
    contents = process_group.find('contents') if process_group is not None else None

    # Generate consistent group ID for all components
    group_id = generate_uuid()

    # Extract processors and connections
    processors = extract_processors(contents, group_id)
    processor_ids = [p['identifier'] for p in processors]
    connections = extract_connections(contents, processor_ids, group_id)

    print(f"  Extracted: {len(processors)} processors, {len(connections)} connections")
    print(f"  Group ID: {group_id}")

    # Generate IDs
    flow_id = generate_uuid()
    pg_id = generate_uuid()
    timestamp = int(datetime.now().timestamp() * 1000)

    # Build complete flow snapshot
    flow_snapshot = {
        "snapshotMetadata": {
            "bucketIdentifier": bucket_id,
            "flowIdentifier": flow_id,
            "version": 1,
            "timestamp": timestamp,
            "author": "admin",
            "comments": "Imported from XML template with full content"
        },
        "flowContents": {
            "identifier": pg_id,
            "instanceIdentifier": pg_id,
            "name": flow_name,
            "comments": flow_desc,
            "position": {"x": 0.0, "y": 0.0},
            "componentType": "PROCESS_GROUP",
            "groupIdentifier": group_id,
            "processors": processors,
            "connections": connections,
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
            "name": flow_name,
            "description": flow_desc,
            "bucketIdentifier": bucket_id,
            "versionCount": 0
        },
        "bucket": {
            "identifier": bucket_id,
            "name": "demo-flows"
        }
    }

    return flow_snapshot


def delete_flow_version(api_url: str, bucket_id: str, flow_id: str, version: int):
    """Delete a specific flow version."""
    try:
        response = requests.delete(
            f"{api_url}/buckets/{bucket_id}/flows/{flow_id}/versions/{version}"
        )
        if response.status_code == 200:
            print(f"  [OK] Deleted version {version}")
            return True
    except Exception as e:
        print(f"  [WARN] Could not delete version: {e}")
    return False


def import_flow_to_registry(
    xml_path: Path,
    registry_url: str,
    bucket_id: str,
    reimport: bool = False
) -> bool:
    """
    Import XML flow to Registry with full content.

    Args:
        xml_path: Path to XML template
        registry_url: Registry URL
        bucket_id: Bucket ID
        reimport: If True, delete existing versions first

    Returns:
        True if successful
    """
    api_url = f"{registry_url}/nifi-registry-api"

    print(f"\n{'='*60}")
    print(f"Importing: {xml_path.name}")
    print(f"{'='*60}")

    try:
        # Parse XML and convert
        snapshot = convert_xml_to_flow_snapshot(xml_path, bucket_id)
        flow_name = snapshot['flow']['name']

        print(f"Flow name: {flow_name}")

        # Check if flow exists
        response = requests.get(f"{api_url}/buckets/{bucket_id}/flows")
        response.raise_for_status()

        flows = response.json()
        existing_flow = None
        for f in flows:
            if f['name'] == flow_name:
                existing_flow = f
                break

        if existing_flow:
            flow_id = existing_flow['identifier']
            print(f"  [INFO] Flow exists: {flow_id}")

            if reimport:
                # Delete all versions
                versions_resp = requests.get(
                    f"{api_url}/buckets/{bucket_id}/flows/{flow_id}/versions"
                )
                if versions_resp.status_code == 200:
                    versions = versions_resp.json()
                    for v in reversed(versions):
                        delete_flow_version(api_url, bucket_id, flow_id, v['version'])
        else:
            # Create new flow
            flow_data = {
                "name": flow_name,
                "description": snapshot['flow']['description'],
                "bucketIdentifier": bucket_id
            }
            response = requests.post(
                f"{api_url}/buckets/{bucket_id}/flows",
                json=flow_data
            )
            response.raise_for_status()
            existing_flow = response.json()
            flow_id = existing_flow['identifier']
            print(f"  [OK] Flow created: {flow_id}")

        # Update snapshot with correct IDs
        snapshot['snapshotMetadata']['flowIdentifier'] = flow_id
        snapshot['snapshotMetadata']['bucketIdentifier'] = bucket_id

        # Import version
        response = requests.post(
            f"{api_url}/buckets/{bucket_id}/flows/{flow_id}/versions",
            json=snapshot,
            headers={"Content-Type": "application/json"}
        )

        if response.status_code != 200:
            print(f"  [ERROR] Import failed: {response.status_code}")
            print(f"  Response: {response.text}")
            return False

        result = response.json()
        print(f"  [SUCCESS] Version {result['snapshotMetadata']['version']} imported")
        return True

    except Exception as e:
        print(f"  [ERROR] Failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main import function."""
    registry_url = "http://localhost:18080"
    bucket_name = "demo-flows"

    print("="*60)
    print("Complete NiFi Registry Flow Importer")
    print("="*60)
    print()

    # Get bucket
    api_url = f"{registry_url}/nifi-registry-api"
    response = requests.get(f"{api_url}/buckets")
    buckets = response.json()

    bucket = None
    for b in buckets:
        if b['name'] == bucket_name:
            bucket = b
            break

    if not bucket:
        print(f"[ERROR] Bucket '{bucket_name}' not found")
        sys.exit(1)

    bucket_id = bucket['identifier']
    print(f"Using bucket: {bucket_name} ({bucket_id})")
    print()

    # Find XML files
    flows_dir = Path(__file__).parent.parent / 'demo' / 'flows'
    xml_files = sorted(flows_dir.glob('0*.xml'))

    if not xml_files:
        print("[ERROR] No XML files found")
        sys.exit(1)

    # Import each flow
    imported = []
    failed = []

    for xml_path in xml_files:
        if import_flow_to_registry(xml_path, registry_url, bucket_id, reimport=True):
            imported.append(xml_path.name)
        else:
            failed.append(xml_path.name)

    # Summary
    print("\n" + "="*60)
    print("Import Summary")
    print("="*60)
    print(f"Total: {len(xml_files)} flows")
    print(f"Imported: {len(imported)}")
    print(f"Failed: {len(failed)}")

    if imported:
        print("\n[SUCCESS] Imported:")
        for name in imported:
            print(f"  - {name}")

    if failed:
        print("\n[ERROR] Failed:")
        for name in failed:
            print(f"  - {name}")


if __name__ == '__main__':
    main()
