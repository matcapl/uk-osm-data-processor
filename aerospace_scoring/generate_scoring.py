#!/usr/bin/env python3
"""Generate SQL scoring expressions and scored‐view DDL from scoring.yaml"""

import yaml
import json
from pathlib import Path
from datetime import datetime

# Only these OSM tables are scored
TABLES = ["planet_osm_point", "planet_osm_line", "planet_osm_polygon"]


def load_configs():
    with open('aerospace_scoring/scoring.yaml') as f:
        scoring = yaml.safe_load(f)
    with open('aerospace_scoring/negative_signals.yaml') as f:
        negative = yaml.safe_load(f)
    with open('aerospace_scoring/schema.json') as f:
        schema = json.load(f)
    return scoring, negative, schema


def check_column_exists(schema, table, column):
    info = schema['tables'].get(table, {})
    if not info.get('exists'):
        return False
    return any(col['name'] == column for col in info.get('columns', []))


def generate_text_search(column, keywords):
    if not keywords:
        return "FALSE"
    conds = [f"LOWER(src.\"{column}\") LIKE LOWER('%{kw}%')" for kw in keywords]
    return "(" + " OR ".join(conds) + ")"


def generate_scoring_sql(scoring, negative, schema):
    sch = schema.get('schema', 'public')
    parts = [
        "-- Aerospace Supplier Scoring SQL",
        f"-- Generated: {datetime.utcnow().isoformat()}",
        f"-- Schema: {sch}",
        ""
    ]

    for tbl in TABLES:
        # Build positive CASE clauses
        pos_clauses = []
        for rule in scoring['scoring_rules'].values():
            w = rule.get('weight', 0)
            conds = []
            for cond in rule.get('conditions', []):
                for col, vals in cond.items():
                    base = col
                    if col.endswith('_contains'):
                        base = col[:-9]
                    if check_column_exists(schema, tbl, base):
                        if col.endswith('_contains'):
                            conds.append(generate_text_search(base, vals))
                        elif '*' in vals:
                            conds.append(f"src.\"{base}\" IS NOT NULL")
                        else:
                            q = "','".join(vals)
                            conds.append(f"src.\"{base}\" IN ('{q}')")
            if conds:
                pos_clauses.append(f"WHEN ({' OR '.join(conds)}) THEN {w}")

        # Keyword bonuses
        bonus_parts = []
        for kb in scoring.get('keyword_bonuses', {}).values():
            w = kb.get('weight', 0)
            kws = kb.get('keywords', [])
            fields = [c for c in ('name','operator','description') if check_column_exists(schema, tbl, c)]
            if fields and kws:
                conds = [generate_text_search(fld, kws) for fld in fields]
                bonus_parts.append(f"CASE WHEN ({' OR '.join(conds)}) THEN {w} ELSE 0 END")

        # Negative signals
        neg_parts = []
        for ns in negative.get('negative_signals', {}).values():
            w = ns.get('weight', 0)
            conds = []
            for cond in ns.get('conditions', []):
                for col, vals in cond.items():
                    if check_column_exists(schema, tbl, col):
                        if '*' in vals:
                            conds.append(f"src.\"{col}\" IS NOT NULL")
                        else:
                            q = "','".join(vals)
                            conds.append(f"src.\"{col}\" IN ('{q}')")
            if conds:
                neg_parts.append(f"CASE WHEN ({' OR '.join(conds)}) THEN {w} ELSE 0 END")

        # Combine scoring parts
        all_parts = []
        if pos_clauses:
            all_parts.append("CASE\n    " + "\n    ".join(pos_clauses) + "\n    ELSE 0\nEND")
        all_parts += bonus_parts + neg_parts
        raw = "0" if not all_parts else "(\n    " + " +\n    ".join(all_parts) + "\n)"
        expr = f"{raw} AS aerospace_score"

        # Emit scored‐view DDL
        parts += [
            f"-- Scored view for {tbl}",
            f"DROP VIEW IF EXISTS {sch}.{tbl}_aerospace_scored CASCADE;",
            f"CREATE VIEW {sch}.{tbl}_aerospace_scored AS",
            "SELECT",
            "  src.*,",
            f"  {expr},",
            "  ARRAY[]::text[] AS matched_keywords,",
            f"  '{tbl}'              AS source_table",
            f"FROM {sch}.{tbl}_aerospace_filtered flt",
            f"JOIN {sch}.{tbl} src ON flt.osm_id = src.osm_id",
            "WHERE",
            f"  {raw} > 0;",
            ""
        ]

    return "\n".join(parts)


def main():
    print("Generating scoring SQL…")
    scoring, negative, schema = load_configs()
    sql_text = generate_scoring_sql(scoring, negative, schema)
    Path('aerospace_scoring/scoring.sql').write_text(sql_text)
    print("✓ Scoring SQL written to aerospace_scoring/scoring.sql")


if __name__ == "__main__":
    main()
