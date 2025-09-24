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
    conditions = []
    for kw in keywords:
        conditions.append("LOWER({col}) LIKE LOWER('%{kw}%')".format(col=column, kw=kw))
    return "(" + " OR ".join(conditions) + ")"

def generate_exact_match_condition(column: str, values: List[str]) -> str:
    if '*' in values:
        return "{col} IS NOT NULL".format(col=column)
    quoted = ", ".join("'{v}'".format(v=v) for v in values)
    return "{col} IN ({vals})".format(col=column, vals=quoted)


def generate_prefix_condition(column: str, prefixes: List[str]) -> str:
    conditions = []
    for p in prefixes:
        conditions.append("UPPER({}) LIKE '{}%'".format(column, p))
    return "({})".format(' OR '.join(conditions))


def check_column_exists(schema: Dict[str, Any], table: str, column: str) -> bool:
    info = schema.get('tables', {}).get(table, {})
    if not info.get('exists'):
        return False
    return any(col['name'] == column for col in info.get('columns', []))


def generate_scoring_case_parts(schema: Dict[str, Any], table: str,
                                rules: Dict[str, Any]) -> List[str]:
    parts = []
    for name, cfg in rules.items():
        if name == 'keyword_bonuses':
            continue
        weight = cfg.get('weight', 0)
        conds = []
        for cond in cfg.get('conditions', []):
            for field, vals in cond.items():
                if field == 'postcode_area':
                    col = 'addr_postcode'
                    if check_column_exists(schema, table, col):
                        conds.append(generate_prefix_condition(col, vals))
                elif field.endswith('_contains'):
                    col = field.replace('_contains','')
                    if check_column_exists(schema, table, col):
                        conds.append(generate_text_search_condition(col, vals))
                else:
                    if check_column_exists(schema, table, field):
                        conds.append(generate_exact_match_condition(field, vals))
        if conds:
            parts.append(f"WHEN ({' OR '.join(conds)}) THEN {weight}")
    return parts


def generate_keyword_bonus_expressions(schema: Dict[str, Any], table: str,
                                       bonuses: Dict[str, Any]) -> List[str]:
    exprs = []
    for cfg in bonuses.values():
        weight = cfg.get('weight', 0)
        kws = cfg.get('keywords', [])
        fields = [f for f in ['name','operator','description','brand']
                  if check_column_exists(schema, table, f)]
        conds = []
        for f in fields:
            conds += [f"LOWER({f}) LIKE LOWER('%{kw}%')" for kw in kws]
        if conds:
            exprs.append(f"CASE WHEN ({' OR '.join(conds)}) THEN {weight} ELSE 0 END")
    return exprs


def generate_negative_expressions(schema: Dict[str, Any], table: str,
                                  signals: Dict[str, Any]) -> List[str]:
    exprs = []
    for key in ['strong_negatives','medium_negatives','weak_negatives','service_negatives']:
        cfg = signals.get(key, {})
        weight = cfg.get('weight',0)
        conds=[]
        for cond in cfg.get('conditions',[]):
            for field, vals in cond.items():
                if field.endswith('_contains'):
                    col=field.replace('_contains','')
                    if check_column_exists(schema,table,col):
                        conds.append(generate_text_search_condition(col,vals))
                else:
                    if check_column_exists(schema,table,field):
                        conds.append(generate_exact_match_condition(field,vals))
        if conds:
            exprs.append(f"CASE WHEN ({' OR '.join(conds)}) THEN {weight} ELSE 0 END")
    # contextual_negatives
    for cfg in signals.get('contextual_negatives',{}).values():
        weight=cfg.get('weight',0)
        all_conds=[]
        for cond in cfg.get('conditions',[]):
            for field, vals in cond.items():
                if field in ['building_area','way_area']:
                    op=vals if isinstance(vals,str) else vals[0]
                    val=op[1:]
                    if op.startswith('<'):
                        all_conds.append(f"{field} < {val}")
                    elif op.startswith('>'):
                        all_conds.append(f"{field} > {val}")
                elif field.endswith('_contains'):
                    col=field.replace('_contains','')
                    if check_column_exists(schema,table,col):
                        all_conds.append(generate_text_search_condition(col,vals))
                else:
                    if check_column_exists(schema,table,field):
                        all_conds.append(generate_exact_match_condition(field,vals))
        if all_conds:
            exprs.append(f"CASE WHEN ({' AND '.join(all_conds)}) THEN {weight} ELSE 0 END")
    return exprs


def generate_complete_scoring_expression(schema: Dict[str, Any], table: str,
                                         scoring: Dict[str, Any],
                                         negative: Dict[str, Any]) -> str:
    pos = generate_scoring_case_parts(schema,table,scoring['scoring_rules'])
    bonus = generate_keyword_bonus_expressions(schema,table,scoring['keyword_bonuses'])
    neg = generate_negative_expressions(schema,table,negative)
    parts = []
    if pos:
        parts.append("CASE\n    "+ "\n    ".join(pos)+"\n    ELSE 0\nEND")
    parts+=bonus+neg
    if not parts:
        return "0 AS aerospace_score"
    expr=" +\n    ".join(parts)
    return f"(\n    {expr}\n) AS aerospace_score"


def generate_matched_keywords_expression(schema: Dict[str, Any], table: str,
                                         scoring: Dict[str, Any]) -> str:
    parts=[]
    for cfg in scoring['keyword_bonuses'].values():
        for kw in cfg.get('keywords',[]):
            fields=[f for f in ['name','operator','description','brand']
                    if check_column_exists(schema,table,f)]
            conds=[f"LOWER({f}) LIKE LOWER('%{kw}%')" for f in fields]
            if conds:
                parts.append(f"CASE WHEN ({' OR '.join(conds)}) THEN '{kw}' END")
    if parts:
        arr="ARRAY["+ ", ".join(parts)+ "]"
        return f"array_remove({arr}, NULL) AS matched_keywords"
    return "ARRAY[]::text[] AS matched_keywords"


def generate_scoring_sql(schema: Dict[str, Any], scoring: Dict[str, Any],
                         negative: Dict[str, Any]) -> str:
    schema_name=schema.get('schema','osm_raw')
    lines=["-- Aerospace Supplier Scoring SQL",
           "-- Generated from scoring.yaml and negative_signals.yaml\n"]
    for table,info in schema['tables'].items():
        if not info.get('exists') or info.get('row_count',0)==0:
            continue
        lines.append(f"-- Scoring for {table}")
        score_expr=generate_complete_scoring_expression(schema,table,scoring,negative)
        match_expr=generate_matched_keywords_expression(schema,table,scoring)
        lines+=[
            "SELECT *,",
            f"    {score_expr},",
            f"    {match_expr},",
            f"    '{table}' AS source_table",
            f"FROM {schema_name}.{table}_aerospace_filtered",
            "WHERE aerospace_score > 0;\n"]
    return "\n".join(lines)


def main() -> int:
    print("Generating scoring SQL from scoring.yaml and negative_signals.yaml...")
    try:
        scoring, negative = load_scoring_config()
        schema = json.loads(Path('schema.json').read_text())
        sql=generate_scoring_sql(schema,scoring,negative)
        Path('scoring.sql').write_text(sql)
        print("✓ Scoring SQL generated: scoring.sql")
        return 0
    except Exception as e:
        print(f"✗ Failed to generate scoring SQL: {e}")
        return 1


if __name__=="__main__":
    exit(main())
