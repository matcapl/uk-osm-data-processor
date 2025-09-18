#!/usr/bin/env python3
"""
xml_stream_sampler.py

Utility for sampling a fixed number of top-level elements
from a large OSM XML stream without loading the full file into memory.

Usage (example):
  osmium tags-filter file.pbf FILTER -f xml -o - | python3 scripts/utils/xml_stream_sampler.py 500 > sample.xml
"""
import sys
import xml.etree.ElementTree as ET

def stream_sample(n, out_stream):
    out_stream.write('<?xml version="1.0" encoding="utf-8"?>\n')
    out_stream.write('<osm version="0.6" generator="xml_stream_sampler">\n')

    count = 0
    # Use iterparse to stream and clear elements to keep memory bounded
    # Note: use sys.stdin.buffer in some environments, but ET.iterparse accepts text streams too
    context = ET.iterparse(sys.stdin, events=("end",))
    for event, elem in context:
        if elem.tag in ("node", "way", "relation"):
            if count < n:
                out_stream.write(ET.tostring(elem, encoding="unicode"))
                count += 1
            # clear to free memory
            elem.clear()
            if count >= n:
                break

    out_stream.write('\n</osm>\n')
    out_stream.flush()

def main():
    if len(sys.argv) != 2:
        print("Usage: xml_stream_sampler.py <max_items>", file=sys.stderr)
        sys.exit(2)
    try:
        max_items = int(sys.argv[1])
    except ValueError:
        print("max_items must be an integer", file=sys.stderr)
        sys.exit(2)
    stream_sample(max_items, sys.stdout)

if __name__ == "__main__":
    main()
