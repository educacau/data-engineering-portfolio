#!/usr/bin/env python3
"""Quick script to import only flow 03"""

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from import_flows_to_registry import RegistryFlowImporter

def main():
    print("Importing flow 03 only...")

    # Initialize importer
    importer = RegistryFlowImporter("http://localhost:18080")

    # Get bucket
    response = importer.session.get(f"{importer.api_url}/buckets")
    buckets = response.json()

    bucket = None
    for b in buckets:
        if b['name'] == 'demo-flows':
            bucket = b
            break

    if not bucket:
        print("ERROR: demo-flows bucket not found")
        sys.exit(1)

    bucket_id = bucket['identifier']
    print(f"Using bucket: {bucket_id}")

    # Import flow 03
    xml_path = Path(__file__).parent.parent / 'demo' / 'flows' / '03-data-quality-pipeline.xml'

    try:
        snapshot = importer.import_xml_template(xml_path, bucket_id)
        print("\n[SUCCESS] Flow 03 imported!")
        print(f"Version: {snapshot['snapshotMetadata']['version']}")
    except Exception as e:
        print(f"\n[ERROR] Failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
