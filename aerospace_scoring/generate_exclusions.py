# ============================================================================
# AEROSPACE SCORING PROCESSING SCRIPTS
# ============================================================================

# File: aerospace_scoring/generate_exclusions.py
"""
Generate SQL exclusion clauses from exclusions.yaml
Converts YAML exclusion rules into WHERE clauses and DELETE statements
"""

import yaml
import json
from pathlib import Path
from typing import Dict, List, Any, Optional

def load_exclusions() -> Dict[str, Any]:
    """Load exclusion rules from YAML file."""
    with open('aerospace_scoring/exclusions.yaml', 'r') as f:
        return yaml.safe_load(f)

def load_schema() -> Dict[str, Any]:
    """Load database schema information."""
    try:
        with open('aerospace_scoring/schema.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("Schema file not found. Run load_schema.py first.")
        raise

def check_column_exists(schema: Dict[str, Any], table: str, column: str) -> bool:
    """Check if a column exists in the specified table."""
    table_info = schema.get('tables', {}).get(table, {})
    if not table_info.get('exists'):
        return False
    
    columns = table_info.get('columns', [])
    return any(col['name'] == column for col in columns)

def generate_exclusion_condition(schema: Dict[str, Any], table: str, 
                                column: str, values: List[str]) -> Optional[str]:
    """Generate a single exclusion condition."""
    if not check_column_exists(schema, table, column):
        return None
    
    if '*' in values:
        # Exclude all non-null values
        return f"{column} IS NULL"
    elif len(values) == 1:
        return f"{column} != '{values[0]}'"
    else:
        quoted_values = "', '".join(values)
        return f"{column} NOT IN ('{quoted_values}')"

def generate_size_exclusion(schema: Dict[str, Any], table: str, 
                           column: str, condition: str) -> Optional[str]:
    """Generate size-based exclusion (e.g., area < 100)."""
    if not check_column_exists(schema, table, column):
        # Try common area column names
        area_columns = ['way_area', 'area', 'st_area', 'building_area']
        column = None
        for col in area_columns:
            if check_column_exists(schema, table, col):
                column = col
                break
        
        if not column:
            return None
    
    # Parse condition like '<100' or '>500'
    if condition.startswith('<'):
        value = condition[1:]
        return f"({column} IS NULL OR {column} >= {value})"
    elif condition.startswith('>'):
        value = condition[1:]
        return f"{column} <= {value}"
    
    return None

def generate_override_condition(schema: Dict[str, Any], table: str, 
                               overrides: Dict[str, List[str]]) -> Optional[str]:
    """Generate conditions for positive overrides that bypass exclusions."""
    conditions = []
    
    for column, values in overrides.items():
        if not check_column_exists(schema, table, column):
            continue
            
        if column.endswith('_contains'):
            # Handle text search conditions
            base_column = column.replace('_contains', '')
            if check_column_exists(schema, table, base_column):
                for value in values:
                    conditions.append(f"LOWER({base_column}) LIKE LOWER('%{value}%')")
        else:
            # Handle exact matches
            if '*' in values:
                conditions.append(f"{column} IS NOT NULL")
            else:
                quoted_values = "', '".join(values)
                conditions.append(f"{column} IN ('{quoted_values}')")
    
    return f"({' OR '.join(conditions)})" if conditions else None

def generate_table_exclusions(schema: Dict[str, Any], exclusions: Dict[str, Any]) -> Dict[str, str]:
    """Generate exclusion WHERE clauses for each table."""
    schema_name = schema.get('schema', 'osm_raw')
    exclusion_clauses = {}
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        conditions = []
        
        # Apply general exclusions
        for category, rules in exclusions['exclusions'].items():
            for rule in rules:
                for column, values in rule.items():
                    if column.endswith('_area'):
                        # Handle size conditions
                        size_condition = generate_size_exclusion(schema, table_name, column, values)
                        if size_condition:
                            conditions.append(size_condition)
                    else:
                        # Handle regular exclusions
                        exclusion_condition = generate_exclusion_condition(schema, table_name, column, values)
                        if exclusion_condition:
                            conditions.append(exclusion_condition)
        
        # Apply table-specific exclusions
        table_exclusions = exclusions.get('table_exclusions', {}).get(table_name, [])
        for rule in table_exclusions:
            for column, values in rule.items():
                exclusion_condition = generate_exclusion_condition(schema, table_name, column, values)
                if exclusion_condition:
                    conditions.append(exclusion_condition)
        
        # Generate override conditions (these BYPASS exclusions)
        override_conditions = []
        for override_category, override_rules in exclusions.get('overrides', {}).items():
            for rule in override_rules:
                override_condition = generate_override_condition(schema, table_name, rule)
                if override_condition:
                    override_conditions.append(override_condition)
        
        # Combine conditions
        if conditions:
            base_exclusions = f"({' AND '.join(conditions)})"
            if override_conditions:
                # Include records that either pass exclusions OR match overrides
                full_condition = f"({base_exclusions} OR {' OR '.join(override_conditions)})"
            else:
                full_condition = base_exclusions
            
            exclusion_clauses[table_name] = full_condition
    
    return exclusion_clauses

def generate_exclusion_sql(exclusion_clauses: Dict[str, str], schema: Dict[str, Any]) -> str:
    """Generate complete SQL for applying exclusions."""
    schema_name = schema.get('schema', 'osm_raw')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Candidate Exclusion SQL")
    sql_parts.append("-- Generated from exclusions.yaml")
    sql_parts.append("-- Apply these filters to exclude non-relevant records\n")
    
    for table_name, where_clause in exclusion_clauses.items():
        sql_parts.append(f"-- Exclusions for {table_name}")
        sql_parts.append(f"-- Records passing filter: ")
        sql_parts.append(f"SELECT COUNT(*) FROM {schema_name}.{table_name} WHERE {where_clause};\n")
        
        # Create filtered view
        view_name = f"{table_name}_aerospace_filtered"
        sql_parts.append(f"CREATE OR REPLACE VIEW {schema_name}.{view_name} AS")
        sql_parts.append(f"SELECT * FROM {schema_name}.{table_name}")
        sql_parts.append(f"WHERE {where_clause};\n")
    
    return "\n".join(sql_parts)

def main():
    """Generate exclusion SQL from YAML configuration."""
    print("Generating exclusion SQL from exclusions.yaml...")
    
    try:
        exclusions = load_exclusions()
        schema = load_schema()
        
        exclusion_clauses = generate_table_exclusions(schema, exclusions)
        exclusion_sql = generate_exclusion_sql(exclusion_clauses, schema)
        
        # Save SQL file
        output_file = Path('aerospace_scoring/exclusions.sql')
        with open(output_file, 'w') as f:
            f.write(exclusion_sql)
        
        print(f"✓ Exclusion SQL generated: {output_file}")
        
        # Show summary
        print("\nExclusion Summary:")
        for table_name, clause in exclusion_clauses.items():
            print(f"  {table_name}: Exclusion filter applied")
        
    except Exception as e:
        print(f"✗ Failed to generate exclusions: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())

