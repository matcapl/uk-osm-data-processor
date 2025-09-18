#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import collections
import sys
from pathlib import Path

def analyze_tags(xml_file):
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        all_tags = collections.defaultdict(set)
        object_counts = collections.defaultdict(int)
        
        for elem in root:
            if elem.tag in ['node', 'way', 'relation']:
                object_counts[elem.tag] += 1
                for tag in elem.findall('tag'):
                    key = tag.get('k')
                    value = tag.get('v')
                    all_tags[key].add(value)
        
        print(f"\n=== Analysis of {xml_file} ===")
        print(f"Object counts: {dict(object_counts)}")
        print(f"Total unique keys: {len(all_tags)}")
        print(f"\nTop 15 most common keys:")
        
        key_counts = {k: len(v) for k, v in all_tags.items()}
        sorted_keys = sorted(key_counts.items(), key=lambda x: x[1], reverse=True)
        
        for key, count in sorted_keys[:15]:
            print(f"  {key}: {count} unique values")
            sample_values = list(all_tags[key])[:3]
            print(f"    Sample values: {sample_values}")
        
        return all_tags, object_counts
        
    except Exception as e:
        print(f"Error analyzing {xml_file}: {e}")
        return {}, {}

if __name__ == "__main__":
    samples_dir = Path('.')
    all_keys = set()
    
    for xml_file in samples_dir.glob('*_sample.xml'):
        tags, counts = analyze_tags(xml_file)
        all_keys.update(tags.keys())
    
    print(f"\n=== SUMMARY ===")
    print(f"Total unique keys across all samples: {len(all_keys)}")
    print(f"\nAll keys found: {sorted(list(all_keys))}")
