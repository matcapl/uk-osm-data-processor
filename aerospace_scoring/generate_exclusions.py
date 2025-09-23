#!/usr/bin/env python3
"""
generate_exclusions.py

Generate SQL exclusion views based on exclusions.yaml configuration.
"""

import yaml
import json
from pathlib import Path
from typing import Any, Dict, List, Optional


def load_config() -> Dict[str, Any]:
    """Load exclusions configuration from YAML."""
    with open('exclusions.yaml', 'r') as f:
        return yaml.safe_load(f)


def load_schema() -> Dict[str, Any]:
    """Load database schema JSON to get list of tables."""
    with open('schema.json', 'r') as f:
        return json.load(f)


def column_exists(schema: Dict[str, Any], table: str, column: str) -> bool:
    """Check if a column exists in the specified table."""
    info = schema.get('tables', {}).get(table, {})
    if not info.get('exists'):
        return False
    return any(col['name'] == column for col in info.get('columns', []))


def build_clause(rule: Dict[str, Any]) -> Optional[str]:
    """Build a positive SQL clause for an exclusion rule."""
    col = rule['column']
    op = rule.get('operator', 'in')
    if op == 'in':
        vals = rule.get('values', [])
        if vals == '*' or vals == ['*']:
            # Exclude any non-null → include only null
            return f"{col} IS NULL"
        quoted = ", ".join(f"'{v}'" for v in vals)
        # Exclude matching → include NOT IN
        return f"{col} NOT IN ({quoted})"
    if op == 'is_not_null':
        # Exclude any non-null → include only null
        return f"{col} IS NULL"
    if op == 'lt':
        # Exclude values less than threshold → include >=
        return f"{col} >= {rule['value']}"
    if op == 'gt':
        # Exclude values greater than threshold → include <=
        return f"{col} <= {rule['value']}"
    return None


def generate_sql() -> str:
    """Generate SQL for exclusion views for all tables."""
    cfg = load_config()
    schema = load_schema()
    tables = [t for t, info in schema['tables'].items() if info.get('exists')]

    defaults: List[Dict[str, Any]] = cfg.get('defaults', [])
    specific: Dict[str, List[Dict[str, Any]]] = cfg.get('table_exclusions', {})

    sql_parts: List[str] = [
        "-- Aerospace Supplier Candidate Exclusion SQL",
        "-- Generated from exclusions.yaml\n"
    ]

    for table in tables:
        clauses: List[str] = []

        # Apply global default exclusions
        for rule in defaults:
            if column_exists(schema, table, rule['column']):
                clause = build_clause(rule)
                if clause:
                    clauses.append(clause)

        # Apply table-specific exclusions
        for rule in specific.get(table, []):
            if column_exists(schema, table, rule['column']):
                clause = build_clause(rule)
                if clause:
                    clauses.append(clause)

        if not clauses:
            continue

        # Wrap combined WHERE clauses in parentheses
        where_sql = "(\n    " + " AND\n    ".join(clauses) + "\n)"
        view_name = f"{table}_aerospace_filtered"

        sql_parts.extend([
            f"-- Exclusions for {table}",
            f"CREATE OR REPLACE VIEW public.{view_name} AS",
            f"SELECT * FROM public.{table}",
            f"WHERE {where_sql};\n"
        ])

    return "\n".join(sql_parts)


def main() -> int:
    """Entry point: write exclusions.sql or print error."""
    try:
        sql = generate_sql()
        Path('exclusions.sql').write_text(sql)
        print("✓ Exclusion SQL generated: exclusions.sql")
        return 0
    except Exception as e:
        print(f"✗ Failed to generate exclusions: {e}")
        return 1


if __name__ == "__main__":
    exit(main())
