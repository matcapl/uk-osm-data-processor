# File: aerospace_scoring/generate_scoring.py
"""
Generate SQL scoring expressions from scoring.yaml and negative_signals.yaml
Creates CASE statements for aerospace supplier scoring
"""

import yaml
import json
from pathlib import Path
from typing import Dict, List, Any, Optional

def load_scoring_config() -> tuple[Dict[str, Any], Dict[str, Any]]:
    """Load scoring and negative signals configuration."""
    with open('aerospace_scoring/scoring.yaml', 'r') as f:
        scoring = yaml.safe_load(f)
    
    with open('aerospace_scoring/negative_signals.yaml', 'r') as f:
        negative_signals = yaml.safe_load(f)
    
    return scoring, negative_signals

def generate_text_search_condition(column: str, keywords: List[str]) -> str:
    """Generate text search condition for keywords in a column."""
    conditions = []
    for keyword in keywords:
        conditions.append(f"LOWER({column}) LIKE LOWER('%{keyword}%')")
    
    return f"({' OR '.join(conditions)})"

def generate_exact_match_condition(column: str, values: List[str]) -> str:
    """Generate exact match condition."""
    if '*' in values:
        return f"{column} IS NOT NULL"
    else:
        quoted_values = "', '".join(values)
        return f"{column} IN ('{quoted_values}')"

def generate_postcode_condition(column: str, postcode_areas: List[str]) -> str:
    """Generate postcode area matching condition."""
    conditions = []
    for area in postcode_areas:
        conditions.append(f"UPPER({column}) LIKE '{area}%'")
    
    return f"({' OR '.join(conditions)})"

def generate_scoring_case_expression(schema: Dict[str, Any], table: str, 
                                   scoring_rules: Dict[str, Any]) -> List[str]:
    """Generate CASE expression parts for positive scoring."""
    case_parts = []
    
    for rule_name, rule_config in scoring_rules.items():
        if rule_name == 'keyword_bonuses':
            continue  # Handle separately
        
        weight = rule_config.get('weight', 0)
        conditions = rule_config.get('conditions', [])
        
        rule_conditions = []
        
        for condition in conditions:
            for field, values in condition.items():
                if not check_column_exists(schema, table, field.replace('_contains', '')):
                    continue
                
                if field.endswith('_contains'):
                    base_field = field.replace('_contains', '')
                    text_condition = generate_text_search_condition(base_field, values)
                    rule_conditions.append(text_condition)
                elif field == 'postcode_area':
                    postcode_condition = generate_postcode_condition('addr:postcode', values)
                    rule_conditions.append(postcode_condition)
                else:
                    exact_condition = generate_exact_match_condition(field, values)
                    rule_conditions.append(exact_condition)
        
        if rule_conditions:
            combined_condition = ' OR '.join(rule_conditions)
            case_parts.append(f"WHEN ({combined_condition}) THEN {weight}")
    
    return case_parts

def generate_keyword_bonus_expression(schema: Dict[str, Any], table: str, 
                                    keyword_bonuses: Dict[str, Any]) -> List[str]:
    """Generate additive keyword bonus expressions."""
    bonus_expressions = []
    
    for bonus_name, bonus_config in keyword_bonuses.items():
        weight = bonus_config.get('weight', 0)
        keywords = bonus_config.get('keywords', [])
        
        # Check multiple text fields for keywords
        text_fields = []
        for field in ['name', 'operator', 'description', 'brand']:
            if check_column_exists(schema, table, field):
                text_fields.append(field)
        
        if text_fields and keywords:
            field_conditions = []
            for field in text_fields:
                keyword_condition = generate_text_search_condition(field, keywords)
                field_conditions.append(keyword_condition)
            
            if field_conditions:
                combined_condition = ' OR '.join(field_conditions)
                bonus_expressions.append(f"CASE WHEN ({combined_condition}) THEN {weight} ELSE 0 END")
    
    return bonus_expressions

def generate_negative_scoring_expression(schema: Dict[str, Any], table: str, 
                                       negative_signals: Dict[str, Any]) -> List[str]:
    """Generate negative scoring expressions."""
    negative_parts = []
    
    for signal_name, signal_config in negative_signals.items():
        if signal_name == 'contextual_negatives':
            continue  # Handle separately
        
        weight = signal_config.get('weight', 0)
        conditions = signal_config.get('conditions', [])
        
        signal_conditions = []
        
        for condition in conditions:
            for field, values in condition.items():
                if not check_column_exists(schema, table, field.replace('_contains', '')):
                    continue
                
                if field.endswith('_contains'):
                    base_field = field.replace('_contains', '')
                    text_condition = generate_text_search_condition(base_field, values)
                    signal_conditions.append(text_condition)
                else:
                    exact_condition = generate_exact_match_condition(field, values)
                    signal_conditions.append(exact_condition)
        
        if signal_conditions:
            combined_condition = ' OR '.join(signal_conditions)
            negative_parts.append(f"CASE WHEN ({combined_condition}) THEN {weight} ELSE 0 END")
    
    return negative_parts

def generate_contextual_negative_expression(schema: Dict[str, Any], table: str, 
                                          contextual_negatives: Dict[str, Any]) -> List[str]:
    """Generate contextual negative scoring (multiple conditions)."""
    contextual_parts = []
    
    for context_name, context_config in contextual_negatives.items():
        weight = context_config.get('weight', 0)
        conditions = context_config.get('conditions', [])
        
        # All conditions must be met for contextual negatives
        all_conditions = []
        
        for condition in conditions:
            for field, values in condition.items():
                if field.endswith('_area'):
                    # Handle area conditions
                    area_field = 'way_area'  # Default area column
                    if check_column_exists(schema, table, area_field):
                        if isinstance(values, str):
                            if values.startswith('<'):
                                all_conditions.append(f"{area_field} < {values[1:]}")
                            elif values.startswith('>'):
                                all_conditions.append(f"{area_field} > {values[1:]}")
                elif field.endswith('_contains'):
                    base_field = field.replace('_contains', '')
                    if check_column_exists(schema, table, base_field):
                        text_condition = generate_text_search_condition(base_field, values)
                        all_conditions.append(text_condition)
                else:
                    if check_column_exists(schema, table, field):
                        exact_condition = generate_exact_match_condition(field, values)
                        all_conditions.append(exact_condition)
        
        if all_conditions:
            combined_condition = ' AND '.join(all_conditions)
            contextual_parts.append(f"CASE WHEN ({combined_condition}) THEN {weight} ELSE 0 END")
    
    return contextual_parts

def check_column_exists(schema: Dict[str, Any], table: str, column: str) -> bool:
    """Check if column exists in table."""
    table_info = schema.get('tables', {}).get(table, {})
    if not table_info.get('exists'):
        return False
    
    columns = table_info.get('columns', [])
    return any(col['name'] == column for col in columns)

def generate_complete_scoring_expression(schema: Dict[str, Any], table: str, 
                                       scoring: Dict[str, Any], negative_signals: Dict[str, Any]) -> str:
    """Generate complete scoring expression for a table."""
    
    # Base scoring rules
    scoring_parts = generate_scoring_case_expression(schema, table, scoring['scoring_rules'])
    
    # Keyword bonuses
    keyword_bonuses = generate_keyword_bonus_expression(schema, table, scoring['keyword_bonuses'])
    
    # Negative signals
    negative_parts = generate_negative_scoring_expression(schema, table, negative_signals)
    
    # Contextual negatives
    contextual_negatives = negative_signals.get('contextual_negatives', {})
    contextual_parts = generate_contextual_negative_expression(schema, table, contextual_negatives)
    
    # Combine all scoring components
    all_parts = []
    
    # Base case statement
    if scoring_parts:
        base_case = "CASE\n    " + "\n    ".join(scoring_parts) + "\n    ELSE 0\nEND"
        all_parts.append(base_case)
    
    # Add keyword bonuses
    all_parts.extend(keyword_bonuses)
    
    # Add negative scoring
    all_parts.extend(negative_parts)
    all_parts.extend(contextual_parts)
    
    # Final expression
    if all_parts:
        return f"(\n    {' +\n    '.join(all_parts)}\n) AS aerospace_score"
    else:
        return "0 AS aerospace_score"

def generate_matched_keywords_expression(schema: Dict[str, Any], table: str, 
                                       scoring: Dict[str, Any]) -> str:
    """Generate expression to capture matched keywords."""
    
    keyword_expressions = []
    
    for bonus_name, bonus_config in scoring['keyword_bonuses'].items():
        keywords = bonus_config.get('keywords', [])
        
        for keyword in keywords:
            text_fields = []
            for field in ['name', 'operator', 'description', 'brand']:
                if check_column_exists(schema, table, field):
                    text_fields.append(f"LOWER({field}) LIKE LOWER('%{keyword}%')")
            
            if text_fields:
                condition = ' OR '.join(text_fields)
                keyword_expressions.append(f"CASE WHEN ({condition}) THEN '{keyword}' END")
    
    if keyword_expressions:
        array_expression = f"ARRAY[{', '.join(keyword_expressions)}]"
        return f"array_remove({array_expression}, NULL) AS matched_keywords"
    else:
        return "ARRAY[]::text[] AS matched_keywords"

def generate_scoring_sql(schema: Dict[str, Any], scoring: Dict[str, Any], 
                        negative_signals: Dict[str, Any]) -> str:
    """Generate complete scoring SQL."""
    
    schema_name = schema.get('schema', 'osm_raw')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Scoring SQL")
    sql_parts.append("-- Generated from scoring.yaml and negative_signals.yaml")
    sql_parts.append("-- Computes aerospace relevance scores for each record\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        sql_parts.append(f"-- Scoring for {table_name}")
        
        scoring_expr = generate_complete_scoring_expression(schema, table_name, scoring, negative_signals)
        keywords_expr = generate_matched_keywords_expression(schema, table_name, scoring)
        
        sql_parts.append(f"SELECT *,")
        sql_parts.append(f"    {scoring_expr},")
        sql_parts.append(f"    {keywords_expr},")
        sql_parts.append(f"    '{table_name}' AS source_table")
        sql_parts.append(f"FROM {schema_name}.{table_name}_aerospace_filtered")
        sql_parts.append(f"WHERE aerospace_score > 0;\n")
    
    return "\n".join(sql_parts)

def main():
    """Generate scoring SQL from YAML configurations."""
    print("Generating scoring SQL from scoring.yaml and negative_signals.yaml...")
    
    try:
        scoring, negative_signals = load_scoring_config()
        
        with open('aerospace_scoring/schema.json', 'r') as f:
            schema = json.load(f)
        
        scoring_sql = generate_scoring_sql(schema, scoring, negative_signals)
        
        # Save SQL file
        output_file = Path('aerospace_scoring/scoring.sql')
        with open(output_file, 'w') as f:
            f.write(scoring_sql)
        
        print(f"✓ Scoring SQL generated: {output_file}")
        
    except Exception as e:
        print(f"✗ Failed to generate scoring SQL: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())