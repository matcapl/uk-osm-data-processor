-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM
-- Generated on: 2025-09-24 18:40:07
-- Database: public

-- STEP 1: Apply exclusion filters
-- Aerospace Supplier Exclusion Filters
-- Generated from exclusions.yaml


-- STEP 2: Apply scoring rules
-- Aerospace Supplier Scoring SQL
-- Generated from scoring.yaml and negative_signals.yaml

-- Scored view for planet_osm_point
CREATE OR REPLACE VIEW public.planet_osm_point_aerospace_scored AS
SELECT *,
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology')) THEN 70
        WHEN (landuse IN ('industrial')) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    ) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_point' AS source_table
FROM public.planet_osm_point_aerospace_filtered
WHERE (
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology')) THEN 70
        WHEN (landuse IN ('industrial')) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    )
) > 0;

-- Scored view for planet_osm_line
CREATE OR REPLACE VIEW public.planet_osm_line_aerospace_scored AS
SELECT *,
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR industrial IN ('engineering', 'electronics', 'precision', 'high_tech') OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology') OR building IN ('industrial', 'factory', 'warehouse')) THEN 70
        WHEN (landuse IN ('industrial') OR building IN ('industrial', 'warehouse', 'manufacture') OR industrial IS NOT NULL) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL OR building IN ('house', 'apartments', 'residential', 'hotel', 'retail')) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    ) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_line' AS source_table
FROM public.planet_osm_line_aerospace_filtered
WHERE (
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR industrial IN ('engineering', 'electronics', 'precision', 'high_tech') OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology') OR building IN ('industrial', 'factory', 'warehouse')) THEN 70
        WHEN (landuse IN ('industrial') OR building IN ('industrial', 'warehouse', 'manufacture') OR industrial IS NOT NULL) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL OR building IN ('house', 'apartments', 'residential', 'hotel', 'retail')) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    )
) > 0;

-- Scored view for planet_osm_polygon
CREATE OR REPLACE VIEW public.planet_osm_polygon_aerospace_scored AS
SELECT *,
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR industrial IN ('engineering', 'electronics', 'precision', 'high_tech') OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology') OR building IN ('industrial', 'factory', 'warehouse')) THEN 70
        WHEN (landuse IN ('industrial') OR building IN ('industrial', 'warehouse', 'manufacture') OR industrial IS NOT NULL) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL OR building IN ('house', 'apartments', 'residential', 'hotel', 'retail')) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    ) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_polygon' AS source_table
FROM public.planet_osm_polygon_aerospace_filtered
WHERE (
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR industrial IN ('engineering', 'electronics', 'precision', 'high_tech') OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology') OR building IN ('industrial', 'factory', 'warehouse')) THEN 70
        WHEN (landuse IN ('industrial') OR building IN ('industrial', 'warehouse', 'manufacture') OR industrial IS NOT NULL) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL OR building IN ('house', 'apartments', 'residential', 'hotel', 'retail')) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    )
) > 0;

-- Scored view for planet_osm_roads
CREATE OR REPLACE VIEW public.planet_osm_roads_aerospace_scored AS
SELECT *,
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR industrial IN ('engineering', 'electronics', 'precision', 'high_tech') OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology') OR building IN ('industrial', 'factory', 'warehouse')) THEN 70
        WHEN (landuse IN ('industrial') OR building IN ('industrial', 'warehouse', 'manufacture') OR industrial IS NOT NULL) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL OR building IN ('house', 'apartments', 'residential', 'hotel', 'retail')) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    ) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_roads' AS source_table
FROM public.planet_osm_roads_aerospace_filtered
WHERE (
    (
        CASE
        WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%bae%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%')) OR office IN ('aerospace', 'aviation')) THEN 100
        WHEN ((LOWER(name) LIKE LOWER('%defense%') OR LOWER(name) LIKE LOWER('%defence%') OR LOWER(name) LIKE LOWER('%military%') OR LOWER(name) LIKE LOWER('%radar%') OR LOWER(name) LIKE LOWER('%missile%') OR LOWER(name) LIKE LOWER('%weapons%')) OR military IS NOT NULL OR landuse IN ('military')) THEN 80
        WHEN ((LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%advanced%')) OR industrial IN ('engineering', 'electronics', 'precision', 'high_tech') OR man_made IN ('works', 'factory') OR office IN ('engineering', 'research', 'technology') OR building IN ('industrial', 'factory', 'warehouse')) THEN 70
        WHEN (landuse IN ('industrial') OR building IN ('industrial', 'warehouse', 'manufacture') OR industrial IS NOT NULL) THEN 50
        WHEN ((LOWER(name) LIKE LOWER('%research%') OR LOWER(name) LIKE LOWER('%development%') OR LOWER(name) LIKE LOWER('%laboratory%') OR LOWER(name) LIKE LOWER('%institute%') OR LOWER(name) LIKE LOWER('%university%')) OR office IN ('research', 'engineering') OR amenity IN ('research_institute', 'university')) THEN 60
        ELSE 0
    END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%')) OR (LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%')) OR (LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
        CASE WHEN ((LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%')) OR (LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
        CASE WHEN (amenity IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school') OR shop IS NOT NULL OR tourism IS NOT NULL OR leisure IS NOT NULL OR building IN ('house', 'apartments', 'residential', 'hotel', 'retail')) THEN -50 ELSE 0 END +
        CASE WHEN (landuse IN ('residential', 'retail', 'commercial', 'farmland')) THEN -25 ELSE 0 END +
        CASE WHEN (office IN ('insurance', 'finance', 'estate_agent', 'lawyer', 'accountant') OR amenity IN ('bank', 'post_office', 'library')) THEN -15 ELSE 0 END
    )
) > 0;


-- STEP 3: Create output table
-- Create aerospace supplier candidates table
DROP TABLE IF EXISTS aerospace_supplier_candidates CASCADE;
CREATE TABLE aerospace_supplier_candidates (
    osm_id BIGINT,
    osm_type VARCHAR(50),
    name TEXT,
    operator TEXT,
    website TEXT,
    phone TEXT,
    postcode VARCHAR(20),
    street_address TEXT,
    city TEXT,
    landuse_type TEXT,
    building_type TEXT,
    industrial_type TEXT,
    office_type TEXT,
    description TEXT,
    geometry GEOMETRY,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    aerospace_score INTEGER,
    tier_classification VARCHAR(50),
    matched_keywords TEXT[],
    confidence_level VARCHAR(20),
    created_at TIMESTAMP,
    source_table VARCHAR(50)
);

-- Create indexes
CREATE INDEX idx_aerospace_score ON aerospace_supplier_candidates(aerospace_score);
CREATE INDEX idx_tier ON aerospace_supplier_candidates(tier_classification);
CREATE INDEX idx_postcode ON aerospace_supplier_candidates(postcode);
CREATE INDEX idx_geom ON aerospace_supplier_candidates USING GIST(geometry);

-- STEP 4: Insert final results
-- Insert aerospace supplier candidates
INSERT INTO aerospace_supplier_candidates (
    osm_id, osm_type, name, operator, website, phone, postcode, street_address, city,
    landuse_type, building_type, industrial_type, office_type, description,
    geometry, latitude, longitude, aerospace_score, tier_classification,
    matched_keywords, confidence_level, created_at, source_table
)
SELECT 
    osm_id,
    source_table AS osm_type,
    COALESCE(name, operator) AS name,
    operator,
    COALESCE(website, "contact:website") AS website,
    COALESCE(phone, "contact:phone") AS phone,
    "addr:postcode" AS postcode,
    "addr:street" AS street_address,
    COALESCE("addr:city", "addr:town") AS city,
    landuse AS landuse_type,
    building AS building_type,
    industrial AS industrial_type,
    office AS office_type,
    description,
    way AS geometry,
    ST_Y(ST_Transform(ST_Centroid(way), 4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(way), 4326)) AS longitude,
    aerospace_score,
    CASE
        WHEN aerospace_score >= 150 THEN 'tier1_candidate'
        WHEN aerospace_score >= 80 THEN 'tier2_candidate'
        WHEN aerospace_score >= 40 THEN 'potential_candidate'
        WHEN aerospace_score >= 10 THEN 'low_probability'
        ELSE 'excluded'
    END AS tier_classification,
    matched_keywords,
    CASE
        WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
        WHEN aerospace_score >= 80 THEN 'medium'
        WHEN aerospace_score >= 40 THEN 'low'
        ELSE 'very_low'
    END AS confidence_level,
    NOW() AS created_at,
    source_table
FROM (
    SELECT * FROM public.planet_osm_point_aerospace_scored
    UNION ALL
    SELECT * FROM public.planet_osm_polygon_aerospace_scored
    UNION ALL
    SELECT * FROM public.planet_osm_line_aerospace_scored
) combined
WHERE aerospace_score >= 10
ORDER BY aerospace_score DESC
LIMIT 5000;

-- STEP 5: Analysis queries
SELECT 'Total candidates' as metric, COUNT(*) as value FROM aerospace_supplier_candidates
UNION ALL
SELECT 'With contact info', COUNT(*) FROM aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL
UNION ALL
SELECT 'High confidence', COUNT(*) FROM aerospace_supplier_candidates WHERE confidence_level = 'high';

-- Classification breakdown
SELECT tier_classification, COUNT(*), AVG(aerospace_score) as avg_score
FROM aerospace_supplier_candidates
GROUP BY tier_classification
ORDER BY avg_score DESC;

-- Top candidates
SELECT name, tier_classification, aerospace_score, postcode
FROM aerospace_supplier_candidates
WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
ORDER BY aerospace_score DESC
LIMIT 20;
