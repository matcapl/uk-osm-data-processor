#!/usr/bin/env python3
"""Generate SQL scoring expressions from scoring.yaml – CORRECTED & EXPANDED"""

import yaml
import json
from pathlib import Path
from datetime import datetime

# Only these OSM tables are scored
TABLES = ["planet_osm_point", "planet_osm_line", "planet_osm_polygon"]

def load_configs():
    """Load scoring rules, negative signals, and detected schema."""
    with open('aerospace_scoring/scoring.yaml', 'r') as f:
        scoring = yaml.safe_load(f)
    with open('aerospace_scoring/negative_signals.yaml', 'r') as f:
        negative = yaml.safe_load(f)
    with open('aerospace_scoring/schema.json', 'r') as f:
        schema = json.load(f)
    return scoring, negative, schema

def check_column_exists(schema, table, column):
    """
    Check if a column exists in the schema.json metadata for a given table.
    Prevents generating SQL against non-existent columns.
    """
    info = schema.get('tables', {}).get(table, {})
    if not info.get('exists'):
        return False
    return any(col['name'] == column for col in info.get('columns', []))

def generate_text_search(column, keywords):
    """
    Build a case-insensitive LIKE clause for a set of keywords on a given column.
    Returns 'FALSE' if no keywords provided to avoid empty parentheses.
    """
    if not keywords:
        return "FALSE"
    conds = [f"LOWER(source.\"{column}\") LIKE LOWER('%{kw}%')" for kw in keywords]
    return "(" + " OR ".join(conds) + ")"

def generate_scoring_sql(scoring, negative, schema):
    """
    Build the full SQL text for scoring views:
      - One CREATE VIEW per table in TABLES
      - CASE for positive rules, keyword bonuses, and negative signals
      - Ensures raw score expression and alias are separated
      - Always emits a view even if filtered data is empty
    """
    sch = schema.get('schema', 'public')
    sql_parts = [
        "-- Aerospace Supplier Scoring SQL",
        f"-- Generated: {datetime.utcnow().isoformat()}",
        f"-- Schema: {sch}",
        ""
    ]

    for tbl in TABLES:
        # Build positive rule CASE clauses
        case_clauses = []
        for rule in scoring['scoring_rules'].values():
            w = rule.get('weight', 0)
            conds = []
            for cond in rule.get('conditions', []):
                for col, vals in cond.items():
                    if col.endswith('_contains'):
                        base = col[:-9]
                        if check_column_exists(schema, tbl, base):
                            conds.append(generate_text_search(base, vals))
                    elif check_column_exists(schema, tbl, col):
                        if '*' in vals:
                            conds.append(f"source.\"{col}\" IS NOT NULL")
                        else:
                            q = "','".join(vals)
                            conds.append(f"source.\"{col}\" IN ('{q}')")
            if conds:
                case_clauses.append(f"WHEN ({' OR '.join(conds)}) THEN {w}")

        # Build keyword bonus expressions
        bonus_parts = []
        for kb in scoring.get('keyword_bonuses', {}).values():
            w = kb.get('weight', 0)
            kws = kb.get('keywords', [])
            fields = [c for c in ('name','operator','description') if check_column_exists(schema, tbl, c)]
            if fields and kws:
                fs = [generate_text_search(c, kws) for c in fields]
                bonus_parts.append(f"CASE WHEN ({' OR '.join(fs)}) THEN {w} ELSE 0 END")

        # Build negative signal expressions
        neg_parts = []
        for ns in negative.get('negative_signals', {}).values():
            w = ns.get('weight', 0)
            conds = []
            for cond in ns.get('conditions', []):
                for col, vals in cond.items():
                    if check_column_exists(schema, tbl, col):
                        if '*' in vals:
                            conds.append(f"source.\"{col}\" IS NOT NULL")
                        else:
                            q = "','".join(vals)
                            conds.append(f"source.\"{col}\" IN ('{q}')")
            if conds:
                neg_parts.append(f"CASE WHEN ({' OR '.join(conds)}) THEN {w} ELSE 0 END")

        # Combine all scoring parts into raw expression
        all_parts = []
        if case_clauses:
            all_parts.append("CASE\n    " + "\n    ".join(case_clauses) + "\n    ELSE 0\nEND")
        all_parts += bonus_parts + neg_parts

        raw = "0"
        if all_parts:
            raw = "(\n    " + " +\n    ".join(all_parts) + "\n)"
        expr = f"{raw} AS aerospace_score"

        # Emit the CREATE VIEW block for this table
        view = f"{tbl}_aerospace_scored"
        sql_parts += [
            f"-- Scored view for {tbl}",
            f"CREATE OR REPLACE VIEW {sch}.{view} AS",
            "SELECT",
            "  source.*,",
            f"  {expr},",
            "  ARRAY[]::text[] AS matched_keywords,",
            f"  '{tbl}' AS source_table",
            f"FROM {sch}.{tbl}_aerospace_filtered filtered",
            f"JOIN {sch}.{tbl} source ON filtered.osm_id = source.osm_id",
            "WHERE",
            f"  {raw} > 0;",
            ""
        ]

    return "\n".join(sql_parts)

def main():
    print("Generating scoring SQL…")
    scoring, negative, schema = load_configs()
    sql_text = generate_scoring_sql(scoring, negative, schema)
    Path('aerospace_scoring/scoring.sql').write_text(sql_text)
    print("✓ Scoring SQL written to aerospace_scoring/scoring.sql")

if __name__ == "__main__":
    main()
