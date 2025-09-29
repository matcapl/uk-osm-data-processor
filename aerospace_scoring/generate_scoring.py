#!/usr/bin/env python3
"""Generate SQL scoring expressions from scoring.yaml - CORRECTED VERSION"""

import yaml
import json
from pathlib import Path

def load_configs():
    with open('aerospace_scoring/scoring.yaml', 'r') as f:
        scoring = yaml.safe_load(f)
    
    with open('aerospace_scoring/negative_signals.yaml', 'r') as f:
        negative_signals = yaml.safe_load(f)
    
    with open('aerospace_scoring/schema.json', 'r') as f:
        schema = json.load(f)
    
    return scoring, negative_signals, schema

def check_column_exists(schema, table, column):
    table_info = schema.get('tables', {}).get(table, {})
    if not table_info.get('exists'):
        return False
    columns = table_info.get('columns', [])
    return any(col['name'] == column for col in columns)

def generate_text_search(column, keywords):
    conditions = []
    for keyword in keywords:
        conditions.append(f'LOWER("{column}") LIKE LOWER(\'%{keyword}%\')')
    return f"({' OR '.join(conditions)})"

def generate_scoring_sql(scoring, negative_signals, schema):
    schema_name = schema.get('schema', 'public')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Scoring SQL")
    sql_parts.append(f"-- Generated from scoring.yaml for schema: {schema_name}")
    sql_parts.append("-- Auto-detected actual schema from database\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        # Build scoring CASE statement
        case_parts = []
        
        # Positive scoring rules
        for rule_name, rule_config in scoring['scoring_rules'].items():
            weight = rule_config.get('weight', 0)
            conditions = rule_config.get('conditions', [])
            
            rule_conditions = []
            for condition in conditions:
                for field, values in condition.items():
                    if field.endswith('_contains'):
                        base_field = field.replace('_contains', '')
                        if check_column_exists(schema, table_name, base_field):
                            text_condition = generate_text_search(base_field, values)
                            rule_conditions.append(text_condition)
                    elif check_column_exists(schema, table_name, field):
                        if '*' in values:
                            rule_conditions.append(f'"{field}" IS NOT NULL')
                        else:
                            quoted_values = "', '".join(values)
                            rule_conditions.append(f'"{field}" IN (\'{quoted_values}\')')
            
            if rule_conditions:
                combined = ' OR '.join(rule_conditions)
                case_parts.append(f"WHEN ({combined}) THEN {weight}")
        
        # Build keyword bonuses
        bonus_expressions = []
        for bonus_name, bonus_config in scoring['keyword_bonuses'].items():
            weight = bonus_config.get('weight', 0)
            keywords = bonus_config.get('keywords', [])
            
            text_fields = []
            for field in ['name', 'operator', 'description']:
                if check_column_exists(schema, table_name, field):
                    text_fields.append(field)
            
            if text_fields and keywords:
                field_conditions = []
                for field in text_fields:
                    keyword_condition = generate_text_search(field, keywords)
                    field_conditions.append(keyword_condition)
                
                combined_condition = ' OR '.join(field_conditions)
                bonus_expressions.append(f"CASE WHEN ({combined_condition}) THEN {weight} ELSE 0 END")
        
        # Build negative scoring
        negative_expressions = []
        for signal_name, signal_config in negative_signals['negative_signals'].items():
            weight = signal_config.get('weight', 0)
            conditions = signal_config.get('conditions', [])
            
            signal_conditions = []
            for condition in conditions:
                for field, values in condition.items():
                    if check_column_exists(schema, table_name, field):
                        if '*' in values:
                            signal_conditions.append(f'"{field}" IS NOT NULL')
                        else:
                            quoted_values = "', '".join(values)
                            signal_conditions.append(f'"{field}" IN (\'{quoted_values}\')')
            
            if signal_conditions:
                combined = ' OR '.join(signal_conditions)
                negative_expressions.append(f"CASE WHEN ({combined}) THEN {weight} ELSE 0 END")
        
        # Combine all scoring components
        all_parts = []
        
        if case_parts:
            base_case = "CASE\n        " + "\n        ".join(case_parts) + "\n        ELSE 0\n    END"
            all_parts.append(base_case)
        
        all_parts.extend(bonus_expressions)
        all_parts.extend(negative_expressions)
        
        if all_parts:
            joined_parts = ' +\n        '.join(all_parts)
            scoring_expr = f"(\n        {joined_parts}\n    ) AS aerospace_score"
        else:
            scoring_expr = "0 AS aerospace_score"
        
        # Create scored view
        view_name = f"{table_name}_aerospace_scored"
        sql_parts.append(f"-- Scored view for {table_name}")
        sql_parts.append(f"CREATE OR REPLACE VIEW {schema_name}.{view_name} AS")
        sql_parts.append(f"SELECT *,")
        sql_parts.append(f"    {scoring_expr},")
        sql_parts.append(f"    ARRAY[]::text[] AS matched_keywords,")
        sql_parts.append(f"    '{table_name}' AS source_table")
        sql_parts.append(f"FROM {schema_name}.{table_name}_aerospace_filtered")
        sql_parts.append(f"WHERE (")
        sql_parts.append(f"    {scoring_expr.replace(' AS aerospace_score', '')}")
        sql_parts.append(f") > 0;\n")
    
    return "\n".join(sql_parts)

def main():
    print("Generating scoring SQL...")
    
    try:
        scoring, negative_signals, schema = load_configs()
        scoring_sql = generate_scoring_sql(scoring, negative_signals, schema)
        
        with open('aerospace_scoring/scoring.sql', 'w') as f:
            f.write(scoring_sql)
        
        print("✓ Scoring SQL generated: aerospace_scoring/scoring.sql")
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
