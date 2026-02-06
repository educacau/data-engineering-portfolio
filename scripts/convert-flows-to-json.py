#!/usr/bin/env python3
"""
Convert NiFi Flow Templates from XML to JSON

NiFi Registry 2.7.2 requires flows in JSON format for versioning.
This script converts all XML flow templates to JSON format.
"""

import json
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, Any, List


def xml_to_dict(element: ET.Element) -> Dict[str, Any]:
    """
    Recursively convert XML element to dictionary.

    Args:
        element: XML element to convert

    Returns:
        Dictionary representation of XML element
    """
    result: Dict[str, Any] = {}

    # Add attributes
    if element.attrib:
        result['@attributes'] = element.attrib

    # Add text content
    if element.text and element.text.strip():
        text_content = element.text.strip()
        if len(element) == 0:  # Leaf node
            return text_content
        result['#text'] = text_content

    # Process child elements
    children: Dict[str, List[Any]] = {}
    for child in element:
        child_data = xml_to_dict(child)
        child_tag = child.tag

        if child_tag in children:
            children[child_tag].append(child_data)
        else:
            children[child_tag] = [child_data]

    # Flatten single-item lists
    for tag, values in children.items():
        if len(values) == 1:
            result[tag] = values[0]
        else:
            result[tag] = values

    return result


def convert_xml_to_json(xml_path: Path, json_path: Path) -> None:
    """
    Convert NiFi XML template to JSON format.

    Args:
        xml_path: Path to XML template file
        json_path: Path to output JSON file
    """
    print(f"Converting {xml_path.name}...")

    try:
        # Parse XML
        tree = ET.parse(xml_path)
        root = tree.getroot()

        # Convert to dictionary
        flow_dict = {
            'template': xml_to_dict(root)
        }

        # Add metadata
        flow_dict['_metadata'] = {
            'source': xml_path.name,
            'format': 'nifi-registry-json',
            'version': '1.0'
        }

        # Write JSON with pretty formatting
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(flow_dict, f, indent=2, ensure_ascii=False)

        print(f"  [OK] Created {json_path.name}")

    except ET.ParseError as e:
        print(f"  [ERROR] Error parsing XML: {e}")
    except Exception as e:
        print(f"  [ERROR] Error: {e}")


def main():
    """Convert all NiFi flow templates from XML to JSON."""

    # Define paths
    flows_dir = Path(__file__).parent.parent / 'demo' / 'flows'

    # Find all XML flow files
    xml_files = sorted(flows_dir.glob('*.xml'))

    if not xml_files:
        print("[ERROR] No XML flow files found in demo/flows/")
        return

    print(f"Found {len(xml_files)} XML flow template(s) to convert\n")

    # Convert each file
    for xml_path in xml_files:
        json_path = xml_path.with_suffix('.json')
        convert_xml_to_json(xml_path, json_path)

    print(f"\n[SUCCESS] Conversion complete! {len(xml_files)} files converted.")
    print("\nNext steps:")
    print("1. Import JSON flows into NiFi Registry")
    print("2. Delete XML files if no longer needed")
    print("3. Update README.md to reference .json extension")


if __name__ == '__main__':
    main()
