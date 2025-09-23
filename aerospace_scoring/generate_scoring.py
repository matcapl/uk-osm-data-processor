#!/usr/bin/env python3
"""
generate_scoring.py

Generate SQL scoring expressions from scoring.yaml and negative_signals.yaml
Creates CASE statements for aerospace supplier scoring
"""

import yaml
import json
from pathlib import Path
from typing import Dict, List, Any, Optional


def load_scoring_config() -> tuple[Dict[str, Any], Dict[str, Any]]:
    """Load scoring and negative signals configuration."""
    with open('scoring.yaml', 'r') as f:
        scoring = yaml.safe_load(f)
    with open('negative_signals.yaml', 'r') as f:
        negative_signals = yaml.safe_load(f)
    return scoring, negative_signals


def generate_text_search_condition(column: str, keywords: List[str]) -> str:
    """Generate text search condition for keywords in a column."""
    conds = [f"LOWER({column}) LIKE LOWER('%{kw}%')" for kw in keywords]
    return f"({' OR '.join(conds)})"


def generate_exact_match_condition(column: str, values: List[str]) -> str:
    """Generate exact match condition."""
    if '*' in values:
        return f"{column} IS NOT NULL"
    quoted = ", ".join(f"'{v}'" for v in values)
    return f"{column} IN ({quoted})"


def generate_prefix_condition(column: str, prefixes: List[str]) -> str:
    """Generate prefix match condition (for postcode areas)."""
    conds = [f"UPPER({column}) LIKE '{p}%'" for p in prefixes]
    return f"({' OR '.join(conds)})"


def check_column_exists(schema: Dict[str, Any], table: str, column: str) -> bool:
    """Check if column exists in table."""
    info = schema.get('tables', {}).get(table, {})
    if not info.get('exists'):
        return False
    return any(col['name'] == column for col in info.get('columns', []))


def generate_scoring_case_parts(schema: Dict[str, Any], table: str,
                                scoring_rules: Dict[str, Any]) -> List[str]:
    """Generate WHEN clauses for positive scoring rules."""
    parts: List[str] = []
    for name, cfg in scoring_rules.items():
        if name == 'keyword_bonuses':
            continue
        weight = cfg.get('weight', 0)
        conds: List[str] = []
        for cond in cfg.get('conditions', []):
            for field, vals in cond.items():
                if field == 'postcode_area':
                    col = 'addr_postcode'
                    if check_column_exists(schema, table, col):
                        conds.append(generate_prefix_condition(col, vals))
                elif field.endswith('_contains'):
                    col = field.replace('_contains', '')
                    if check_column_exists(schema, table, col):
                        conds.append(generate_text_search_condition(col, vals))
                else:
                    if check_column_exists(schema, table, field):
                        conds.append(generate_exact_match_condition(field, vals))
        if conds:
            parts.append(f"WHEN ({' OR '.join(conds)}) THEN {weight}")
    return parts


def generate_keyword_bonus_expressions(schema: Dict[str, Any], table: str,
                                       keyword_bonuses: Dict[str, Any]) -> List[str]:
    """Generate CASE expressions for keyword bonuses."""
    exprs: List[str] = []
    for _, cfg in keyword_bonuses.items():
        weight = cfg.get('weight', 0)
        kws = cfg.get('keywords', [])
        fields = [f for f in ['name','operator','description','brand'] if check_column_exists(schema, table, f)]
        if not fields or not kws:
            continue
        conds = []
        for f in fields:
            conds.extend([f"LOWER({f}) LIKE LOWER('%{kw}%')" for kw in kws])
        exprs.append(f"CASE WHEN ({' OR '.join(conds)}) THEN {weight} ELSE 0 END")
    return exprs


def generate_negative_expressions(schema: Dict[str, Any], table: str,
                                  negative_signals: Dict[str, Any]) -> List[str]:
    """Generate CASE expressions for negative and contextual negative signals."""
    exprs: List[str] = []
    # strong, medium, weak, service_negatives
    for key in ['strong_negatives','medium_negatives','weak_negatives','service_negatives']:
        cfg = negative_signals.get(key, {})
        weight = cfg.get('weight', 0)
        conds: List[str] = []
        for cond in cfg.get('conditions', []):
            for field, vals in cond.items():
                if field.endswith('_contains'):
                    col = field.replace('_contains','')
                    if check_column_exists(schema, table, col):
                        conds.append(generate_text_search_condition(col, vals))
                else:
                    if check_column_exists(schema, table, field):
                        expr = generate_exact_match_condition(field, vals)
                        conds.append(expr)
        if conds:
            exprs.append(f"CASE WHEN ({' OR '.join(conds)}) THEN {weight} ELSE 0 END")
    # contextual_negatives
    for cfg in negative_signals.get('contextual_negatives', {}).values():
        weight = cfg.get('weight', 0)
        conds_all: List[str] = []
        for cond in cfg.get('conditions', []):
            for field, vals in cond.items():
                if field in ['building_area','way_area']:
                    op = vals[0] if isinstance(vals, list) else vals
                    val = op[1:]
                    if op.startswith('<'):
                        conds_all.append(f"{field} < {val}")
                    elif op.startswith('>'):
                        conds_all.append(f"{field} > {val}")
                elif field.endswith('_contains'):
                    col = field.replace('_contains','')
                    if check_column_exists(schema, table, col):
                        conds_all.append(generate_text_search_condition(col, vals))
                else:
                    if check_column_exists(schema, table, field):
                        conds_all.append(generate_exact_match_condition(field, vals))
        if conds_all:
            exprs.append(f"CASE WHEN ({' AND '.join(conds_all)}) THEN {weight} ELSE 0 END")
    return exprs


def generate_complete_scoring_expression(schema: Dict[str, Any], table: str,
                                         scoring: Dict[str, Any],
                                         negative: Dict[str, Any]) -> str:
    """Combine positive, keyword, and negative scoring into one expression."""
    pos = generate_scoring_case_parts(schema, table, scoring['scoring_rules'])
    bonus = generate_keyword_bonus_expressions(schema, table, scoring['keyword_bonuses'])
    neg = generate_negative_expressions(schema, table, negative)

    all_parts = []
    if pos:
        all_parts.append("CASE\n    " + "\n    ".join(pos) + "\n    ELSE 0\nEND")
    all_parts.extend(bonus)
    all_parts.extend(neg)

    if not all_parts:
        return "0 AS aerospace_score"

    expr = " +\n    ".join(all_parts)
    return f"(\n    {expr}\n) AS aerospace_score"


def generate_matched_keywords_expression(schema: Dict[str, Any], table: str,
                                         scoring: Dict[str, Any]) -> str:
    """Build array of matched keywords."""
    parts: List[str] = []
    for cfg in scoring['keyword_bonuses'].values():
        for kw in cfg.get('keywords', []):
            fields = [f for f in ['name','operator','description','brand'] if check_column_exists(schema, table, f)]
            conds = [f"LOWER({f}) LIKE LOWER('%{kw}%')" for f in fields]
            if conds:
                parts.append(f"CASE WHEN ({' OR '.join(conds)}) THEN '{kw}' END")
    if parts:
        arr = "ARRAY[" + ", ".join(parts) + "]"
        return f"array_remove({arr}, NULL) AS matched_keywords"
    return "ARRAY[]::text[] AS matched_keywords"


def generate_scoring_sql(schema: Dict[str, Any], scoring: Dict[str, Any],
                         negative: Dict[str, Any]) -> str:
    """Generate full scoring SQL for each filtered table."""
    schema_name = schema.get('schema', 'osm_raw')
    lines: List[str] = [
        "-- Aerospace Supplier Scoring SQL",
        "-- Generated from scoring.yaml and negative_signals.yaml\n"
    ]
    for table, info in schema['tables'].items():
        if not info.get('exists') or info.get('row_count',0)==0:
            continue
        lines.append(f"-- Scoring for {table}")
        score_expr = generate_complete_scoring_expression(schema, table, scoring, negative)
        match_expr = generate_matched_keywords_expression(schema, table, scoring)
        lines.extend([
            "SELECT *,",
            f"    {score_expr},",
            f"    {match_expr},",
            f"    '{table}' AS source_table",
            f"FROM {schema_name}.{table}_aerospace_filtered",
            "WHERE aerospace_score > 0;\n"
        ])
    return "\n".join(lines)


def main() -> int:
    print("Generating scoring SQL from scoring.yaml and negative_signals.yaml...")
    try:
        scoring, negative = load_scoring_config()
        schema = json.loads(Path('schema.json').read_text())
        sql = generate_scoring_sql(schema, scoring, negative)
        Path('scoring.sql').write_text(sql)
        print("✓ Scoring SQL generated: scoring.sql")
        return 0
    except Exception as e:
        print(f"✗ Failed to generate scoring SQL: {e}")
        return 1


if __name__ == "__main__":
    exit(main())
