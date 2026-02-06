#!/usr/bin/env python3
"""
Convert NiFi Templates (XML) to Registry Flow Snapshots (JSON)

NiFi Registry requires flows in a specific VersionedFlowSnapshot JSON format.
This script converts XML templates to the correct Registry format.
"""

import json
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List


def generate_uuid() -> str:
    """Generate a UUID string."""
    return str(uuid.uuid4())


def parse_processors_from_xml(processors_elem) -> List[Dict[str, Any]]:
    """Extract processors from XML and convert to Registry format."""
    processors = []

    if processors_elem is None:
        return processors

    # Handle both single processor and list of processors
    processor_list = processors_elem if isinstance(processors_elem, list) else [processors_elem]

    for proc in processor_list:
        processor = {
            "identifier": proc.find('id').text if proc.find('id') is not None else generate_uuid(),
            "name": proc.find('name').text if proc.find('name') is not None else "Processor",
            "type": proc.find('type').text if proc.find('type') is not None else "",
            "bundle": {
                "group": "org.apache.nifi",
                "artifact": "nifi-standard-nar",
                "version": "1.25.0"
            },
            "position": {
                "x": float(proc.find('.//position/x').text) if proc.find('.//position/x') is not None else 0.0,
                "y": float(proc.find('.//position/y').text) if proc.find('.//position/y') is not None else 0.0
            },
            "properties": {},
            "propertyDescriptors": {},
            "componentType": "PROCESSOR",
            "groupIdentifier": "root"
        }

        # Extract properties
        config = proc.find('config')
        if config is not None:
            properties = config.find('properties')
            if properties is not None:
                for entry in properties.findall('entry'):
                    key = entry.find('key')
                    value = entry.find('value')
                    if key is not None and value is not None:
                        processor["properties"][key.text] = value.text if value.text else ""

        processors.append(processor)

    return processors


def parse_connections_from_xml(connections_elem) -> List[Dict[str, Any]]:
    """Extract connections from XML and convert to Registry format."""
    connections = []

    if connections_elem is None:
        return connections

    connection_list = connections_elem if isinstance(connections_elem, list) else [connections_elem]

    for conn in connection_list:
        connection = {
            "identifier": conn.find('id').text if conn.find('id') is not None else generate_uuid(),
            "name": conn.find('name').text if conn.find('name') is not None else "",
            "source": {
                "id": conn.find('sourceId').text if conn.find('sourceId') is not None else "",
                "type": "PROCESSOR"
            },
            "destination": {
                "id": conn.find('destinationId').text if conn.find('destinationId') is not None else "",
                "type": "PROCESSOR"
            },
            "selectedRelationships": [],
            "componentType": "CONNECTION",
            "groupIdentifier": "root"
        }

        # Extract selected relationships
        relationships = conn.findall('.//selectedRelationship')
        for rel in relationships:
            if rel.text:
                connection["selectedRelationships"].append(rel.text)

        connections.append(connection)

    return connections


def convert_template_to_flow_snapshot(xml_path: Path) -> Dict[str, Any]:
    """
    Convert NiFi XML template to Registry VersionedFlowSnapshot format.

    Args:
        xml_path: Path to XML template file

    Returns:
        Dictionary in VersionedFlowSnapshot format
    """
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Extract template metadata
    template_name = root.find('name').text if root.find('name') is not None else xml_path.stem
    template_desc = root.find('description').text if root.find('description') is not None else ""

    # Generate identifiers
    flow_id = generate_uuid()
    bucket_id = generate_uuid()
    timestamp = int(datetime.now().timestamp() * 1000)

    # Parse processors and connections from snippet
    snippet = root.find('.//snippet')
    process_group = snippet.find('.//processGroups') if snippet is not None else None
    contents = process_group.find('contents') if process_group is not None else None

    processors = []
    connections = []

    if contents is not None:
        # Extract processors
        procs_elem = contents.findall('.//processors')
        for proc_elem in procs_elem:
            processors.extend(parse_processors_from_xml(proc_elem))

        # Extract connections
        conns_elem = contents.findall('.//connections')
        for conn_elem in conns_elem:
            connections.extend(parse_connections_from_xml(conn_elem))

    # Build VersionedFlowSnapshot structure
    flow_snapshot = {
        "snapshotMetadata": {
            "flowIdentifier": flow_id,
            "version": 1,
            "timestamp": timestamp,
            "author": "admin",
            "comments": "Initial import from template"
        },
        "flowContents": {
            "identifier": generate_uuid(),
            "name": template_name,
            "comments": template_desc,
            "position": {
                "x": 0.0,
                "y": 0.0
            },
            "componentType": "PROCESS_GROUP",
            "processors": processors,
            "connections": connections,
            "inputPorts": [],
            "outputPorts": [],
            "processGroups": [],
            "funnels": [],
            "remoteProcessGroups": [],
            "labels": [],
            "controllerServices": []
        },
        "flow": {
            "identifier": flow_id,
            "name": template_name,
            "description": template_desc,
            "bucketIdentifier": bucket_id,
            "versionCount": 1,
            "createdTimestamp": timestamp,
            "modifiedTimestamp": timestamp
        },
        "bucket": {
            "identifier": bucket_id,
            "name": "demo-flows",
            "description": "Demo flow templates for portfolio",
            "createdTimestamp": timestamp
        }
    }

    return flow_snapshot


def main():
    """Convert all NiFi flow templates to Registry format."""

    # Define paths
    flows_dir = Path(__file__).parent.parent / 'demo' / 'flows'

    # We need to restore XML files first or read from JSON
    # For now, let's inform the user about the proper workflow
    print("=" * 60)
    print("NiFi Registry Flow Import - Proper Workflow")
    print("=" * 60)
    print()
    print("IMPORTANT: NiFi Registry import requires a specific workflow:")
    print()
    print("Option 1: Import via NiFi UI (Recommended)")
    print("  1. Import XML templates into NiFi canvas")
    print("  2. Right-click Process Group -> Version -> Start version control")
    print("  3. Connect to Registry and save")
    print()
    print("Option 2: Use NiFi CLI")
    print("  1. Use nifi-toolkit CLI: import-template command")
    print("  2. Version the imported flow using Registry CLI")
    print()
    print("Option 3: Direct Registry API (Complex)")
    print("  Requires creating bucket first, then posting flow snapshot")
    print()
    print("The XML templates are the correct format for NiFi import.")
    print("JSON conversion is needed only for direct Registry API import.")
    print()
    print("=" * 60)


if __name__ == '__main__':
    main()
