SET search_path = public;

-- ================================================================================
-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM
-- Generated on: 2025-09-23 23:29:53
-- ================================================================================

-- STEP 1: Create output table
-- Create aerospace supplier candidates table
-- Tier-2 aerospace supplier candidates from UK OSM data
DROP TABLE IF EXISTS aerospace_supplier_candidates CASCADE;
CREATE TABLE aerospace_supplier_candidates (
    osm_id BIGINT,
    osm_type VARCHAR(50),
    name TEXT,
    operator TEXT,
    website TEXT,
    phone TEXT,
    email TEXT,
    postcode VARCHAR(20),
    street_address TEXT,
    city TEXT,
    county TEXT,
    landuse_type TEXT,
    building_type TEXT,
    industrial_type TEXT,
    office_type TEXT,
    description TEXT,
    brand TEXT,
    geometry GEOMETRY,
    centroid GEOMETRY,
    area_sqm DOUBLE PRECISION,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    aerospace_score INTEGER,
    tier_classification VARCHAR(50),
    matched_keywords TEXT[],
    confidence_level VARCHAR(20),
    created_at TIMESTAMP,
    data_source VARCHAR(50),
    processing_notes TEXT
);

-- Create indexes for performance
CREATE INDEX idx_aerospace_supplier_candidates_score ON aerospace_supplier_candidates(aerospace_score);
CREATE INDEX idx_aerospace_supplier_candidates_tier ON aerospace_supplier_candidates(tier_classification);
CREATE INDEX idx_aerospace_supplier_candidates_postcode ON aerospace_supplier_candidates(postcode);
CREATE INDEX idx_aerospace_supplier_candidates_geom ON aerospace_supplier_candidates USING GIST(geometry);

-- STEP 2: Apply exclusion filters
BEGIN;
-- Aerospace Supplier Candidate Exclusion SQL
-- Generated from exclusions.yaml

-- Exclusions for planet_osm_point
CREATE OR REPLACE VIEW public.planet_osm_point_aerospace_filtered AS
SELECT * FROM public.planet_osm_point
WHERE (
    landuse NOT IN ('residential', 'retail', 'commercial') AND
    amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy') AND
    shop IS NULL AND
    tourism IS NULL AND
    leisure NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course') AND
    highway IS NULL AND
    railway NOT IN ('station', 'halt', 'platform') AND
    waterway IS NULL AND
    natural IS NULL AND
    barrier IS NULL AND
    landuse NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill') AND
    man_made NOT IN ('water_tower', 'water_works', 'sewage_plant') AND
    amenity NOT IN ('fuel', 'parking') AND
    shop IS NULL AND
    tourism IS NULL
);

-- Exclusions for planet_osm_line
CREATE OR REPLACE VIEW public.planet_osm_line_aerospace_filtered AS
SELECT * FROM public.planet_osm_line
WHERE (
    landuse NOT IN ('residential', 'retail', 'commercial') AND
    building NOT IN ('house', 'apartments', 'residential', 'hotel', 'retail', 'supermarket') AND
    amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy') AND
    shop IS NULL AND
    tourism IS NULL AND
    leisure NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course') AND
    highway IS NULL AND
    railway NOT IN ('station', 'halt', 'platform') AND
    waterway IS NULL AND
    natural IS NULL AND
    barrier IS NULL AND
    landuse NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill') AND
    man_made NOT IN ('water_tower', 'water_works', 'sewage_plant') AND
    highway NOT IN ('footway', 'cycleway', 'path', 'steps') AND
    railway NOT IN ('abandoned', 'disused')
);

-- Exclusions for planet_osm_polygon
CREATE OR REPLACE VIEW public.planet_osm_polygon_aerospace_filtered AS
SELECT * FROM public.planet_osm_polygon
WHERE (
    landuse NOT IN ('residential', 'retail', 'commercial') AND
    building NOT IN ('house', 'apartments', 'residential', 'hotel', 'retail', 'supermarket') AND
    amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy') AND
    shop IS NULL AND
    tourism IS NULL AND
    leisure NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course') AND
    highway IS NULL AND
    railway NOT IN ('station', 'halt', 'platform') AND
    waterway IS NULL AND
    natural IS NULL AND
    barrier IS NULL AND
    landuse NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill') AND
    man_made NOT IN ('water_tower', 'water_works', 'sewage_plant') AND
    building NOT IN ('house', 'apartments', 'residential') AND
    landuse NOT IN ('residential', 'farmland', 'forest')
);

-- Exclusions for planet_osm_roads
CREATE OR REPLACE VIEW public.planet_osm_roads_aerospace_filtered AS
SELECT * FROM public.planet_osm_roads
WHERE (
    landuse NOT IN ('residential', 'retail', 'commercial') AND
    building NOT IN ('house', 'apartments', 'residential', 'hotel', 'retail', 'supermarket') AND
    amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy') AND
    shop IS NULL AND
    tourism IS NULL AND
    leisure NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course') AND
    highway IS NULL AND
    railway NOT IN ('station', 'halt', 'platform') AND
    waterway IS NULL AND
    natural IS NULL AND
    barrier IS NULL AND
    landuse NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill') AND
    man_made NOT IN ('water_tower', 'water_works', 'sewage_plant')
);

COMMIT;

-- STEP 3: Apply scoring rules
CREATE VIEW planet_osm_point_aerospace_scored AS
SELECT *,
    (
    CASE
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 80
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 50
    ELSE 0
END +
    CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 50 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 30 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 20 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%software%') OR LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 25 ELSE 0 END +
    CASE WHEN (operator IN ('l', 't')) THEN -30 ELSE 0 END +
    CASE WHEN (operator IN ('g', 't')) THEN -40 ELSE 0 END
) AS aerospace_score,
    array_remove(ARRAY[CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%boeing%')) THEN 'boeing' END, CASE WHEN (LOWER(name) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%airbus%')) THEN 'airbus' END, CASE WHEN (LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%rolls royce%')) THEN 'rolls royce' END, CASE WHEN (LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%bae systems%')) THEN 'bae systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%leonardo%')) THEN 'leonardo' END, CASE WHEN (LOWER(name) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%thales%')) THEN 'thales' END, CASE WHEN (LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 'safran' END, CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aerospace%')) THEN 'aerospace' END, CASE WHEN (LOWER(name) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aviation%')) THEN 'aviation' END, CASE WHEN (LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%aircraft%')) THEN 'aircraft' END, CASE WHEN (LOWER(name) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%avionics%')) THEN 'avionics' END, CASE WHEN (LOWER(name) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%turbine%')) THEN 'turbine' END, CASE WHEN (LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 'engine' END, CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%precision%')) THEN 'precision' END, CASE WHEN (LOWER(name) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%machining%')) THEN 'machining' END, CASE WHEN (LOWER(name) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%casting%')) THEN 'casting' END, CASE WHEN (LOWER(name) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%forging%')) THEN 'forging' END, CASE WHEN (LOWER(name) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%composite%')) THEN 'composite' END, CASE WHEN (LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 'materials' END, CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%engineering%')) THEN 'engineering' END, CASE WHEN (LOWER(name) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%technology%')) THEN 'technology' END, CASE WHEN (LOWER(name) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%systems%')) THEN 'systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%electronics%')) THEN 'electronics' END, CASE WHEN (LOWER(name) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%software%')) THEN 'software' END, CASE WHEN (LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 'control' END], NULL) AS matched_keywords,
    'planet_osm_point' AS source_table
FROM public.planet_osm_point_aerospace_filtered
WHERE aerospace_score > 0;


CREATE VIEW planet_osm_line_aerospace_scored AS
SELECT *,
    (
    CASE
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 80
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 50
    ELSE 0
END +
    CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 50 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 30 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 20 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%software%') OR LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 25 ELSE 0 END +
    CASE WHEN (operator IN ('l', 't')) THEN -30 ELSE 0 END +
    CASE WHEN (operator IN ('g', 't')) THEN -40 ELSE 0 END
) AS aerospace_score,
    array_remove(ARRAY[CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%boeing%')) THEN 'boeing' END, CASE WHEN (LOWER(name) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%airbus%')) THEN 'airbus' END, CASE WHEN (LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%rolls royce%')) THEN 'rolls royce' END, CASE WHEN (LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%bae systems%')) THEN 'bae systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%leonardo%')) THEN 'leonardo' END, CASE WHEN (LOWER(name) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%thales%')) THEN 'thales' END, CASE WHEN (LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 'safran' END, CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aerospace%')) THEN 'aerospace' END, CASE WHEN (LOWER(name) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aviation%')) THEN 'aviation' END, CASE WHEN (LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%aircraft%')) THEN 'aircraft' END, CASE WHEN (LOWER(name) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%avionics%')) THEN 'avionics' END, CASE WHEN (LOWER(name) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%turbine%')) THEN 'turbine' END, CASE WHEN (LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 'engine' END, CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%precision%')) THEN 'precision' END, CASE WHEN (LOWER(name) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%machining%')) THEN 'machining' END, CASE WHEN (LOWER(name) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%casting%')) THEN 'casting' END, CASE WHEN (LOWER(name) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%forging%')) THEN 'forging' END, CASE WHEN (LOWER(name) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%composite%')) THEN 'composite' END, CASE WHEN (LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 'materials' END, CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%engineering%')) THEN 'engineering' END, CASE WHEN (LOWER(name) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%technology%')) THEN 'technology' END, CASE WHEN (LOWER(name) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%systems%')) THEN 'systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%electronics%')) THEN 'electronics' END, CASE WHEN (LOWER(name) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%software%')) THEN 'software' END, CASE WHEN (LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 'control' END], NULL) AS matched_keywords,
    'planet_osm_line' AS source_table
FROM public.planet_osm_line_aerospace_filtered
WHERE aerospace_score > 0;


CREATE VIEW planet_osm_polygon_aerospace_scored AS
SELECT *,
    (
    CASE
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 80
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 50
    ELSE 0
END +
    CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 50 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 30 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 20 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%software%') OR LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 25 ELSE 0 END +
    CASE WHEN (operator IN ('l', 't')) THEN -30 ELSE 0 END +
    CASE WHEN (operator IN ('g', 't')) THEN -40 ELSE 0 END
) AS aerospace_score,
    array_remove(ARRAY[CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%boeing%')) THEN 'boeing' END, CASE WHEN (LOWER(name) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%airbus%')) THEN 'airbus' END, CASE WHEN (LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%rolls royce%')) THEN 'rolls royce' END, CASE WHEN (LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%bae systems%')) THEN 'bae systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%leonardo%')) THEN 'leonardo' END, CASE WHEN (LOWER(name) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%thales%')) THEN 'thales' END, CASE WHEN (LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 'safran' END, CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aerospace%')) THEN 'aerospace' END, CASE WHEN (LOWER(name) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aviation%')) THEN 'aviation' END, CASE WHEN (LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%aircraft%')) THEN 'aircraft' END, CASE WHEN (LOWER(name) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%avionics%')) THEN 'avionics' END, CASE WHEN (LOWER(name) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%turbine%')) THEN 'turbine' END, CASE WHEN (LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 'engine' END, CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%precision%')) THEN 'precision' END, CASE WHEN (LOWER(name) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%machining%')) THEN 'machining' END, CASE WHEN (LOWER(name) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%casting%')) THEN 'casting' END, CASE WHEN (LOWER(name) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%forging%')) THEN 'forging' END, CASE WHEN (LOWER(name) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%composite%')) THEN 'composite' END, CASE WHEN (LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 'materials' END, CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%engineering%')) THEN 'engineering' END, CASE WHEN (LOWER(name) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%technology%')) THEN 'technology' END, CASE WHEN (LOWER(name) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%systems%')) THEN 'systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%electronics%')) THEN 'electronics' END, CASE WHEN (LOWER(name) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%software%')) THEN 'software' END, CASE WHEN (LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 'control' END], NULL) AS matched_keywords,
    'planet_osm_polygon' AS source_table
FROM public.planet_osm_polygon_aerospace_filtered
WHERE aerospace_score > 0;


CREATE VIEW planet_osm_roads_aerospace_scored AS
SELECT *,
    (
    CASE
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 80
    WHEN (operator IN ('i', 's', '_', 'n', 'o', 't', '_', 'n', 'u', 'l', 'l')) THEN 50
    ELSE 0
END +
    CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(name) LIKE LOWER('%airbus%') OR LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(name) LIKE LOWER('%thales%') OR LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 50 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(name) LIKE LOWER('%aviation%') OR LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(name) LIKE LOWER('%avionics%') OR LOWER(name) LIKE LOWER('%turbine%') OR LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 30 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(name) LIKE LOWER('%machining%') OR LOWER(name) LIKE LOWER('%casting%') OR LOWER(name) LIKE LOWER('%forging%') OR LOWER(name) LIKE LOWER('%composite%') OR LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 20 ELSE 0 END +
    CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(name) LIKE LOWER('%technology%') OR LOWER(name) LIKE LOWER('%systems%') OR LOWER(name) LIKE LOWER('%electronics%') OR LOWER(name) LIKE LOWER('%software%') OR LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 25 ELSE 0 END +
    CASE WHEN (operator IN ('l', 't')) THEN -30 ELSE 0 END +
    CASE WHEN (operator IN ('g', 't')) THEN -40 ELSE 0 END
) AS aerospace_score,
    array_remove(ARRAY[CASE WHEN (LOWER(name) LIKE LOWER('%boeing%') OR LOWER(operator) LIKE LOWER('%boeing%') OR LOWER(brand) LIKE LOWER('%boeing%')) THEN 'boeing' END, CASE WHEN (LOWER(name) LIKE LOWER('%airbus%') OR LOWER(operator) LIKE LOWER('%airbus%') OR LOWER(brand) LIKE LOWER('%airbus%')) THEN 'airbus' END, CASE WHEN (LOWER(name) LIKE LOWER('%rolls royce%') OR LOWER(operator) LIKE LOWER('%rolls royce%') OR LOWER(brand) LIKE LOWER('%rolls royce%')) THEN 'rolls royce' END, CASE WHEN (LOWER(name) LIKE LOWER('%bae systems%') OR LOWER(operator) LIKE LOWER('%bae systems%') OR LOWER(brand) LIKE LOWER('%bae systems%')) THEN 'bae systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%leonardo%') OR LOWER(operator) LIKE LOWER('%leonardo%') OR LOWER(brand) LIKE LOWER('%leonardo%')) THEN 'leonardo' END, CASE WHEN (LOWER(name) LIKE LOWER('%thales%') OR LOWER(operator) LIKE LOWER('%thales%') OR LOWER(brand) LIKE LOWER('%thales%')) THEN 'thales' END, CASE WHEN (LOWER(name) LIKE LOWER('%safran%') OR LOWER(operator) LIKE LOWER('%safran%') OR LOWER(brand) LIKE LOWER('%safran%')) THEN 'safran' END, CASE WHEN (LOWER(name) LIKE LOWER('%aerospace%') OR LOWER(operator) LIKE LOWER('%aerospace%') OR LOWER(brand) LIKE LOWER('%aerospace%')) THEN 'aerospace' END, CASE WHEN (LOWER(name) LIKE LOWER('%aviation%') OR LOWER(operator) LIKE LOWER('%aviation%') OR LOWER(brand) LIKE LOWER('%aviation%')) THEN 'aviation' END, CASE WHEN (LOWER(name) LIKE LOWER('%aircraft%') OR LOWER(operator) LIKE LOWER('%aircraft%') OR LOWER(brand) LIKE LOWER('%aircraft%')) THEN 'aircraft' END, CASE WHEN (LOWER(name) LIKE LOWER('%avionics%') OR LOWER(operator) LIKE LOWER('%avionics%') OR LOWER(brand) LIKE LOWER('%avionics%')) THEN 'avionics' END, CASE WHEN (LOWER(name) LIKE LOWER('%turbine%') OR LOWER(operator) LIKE LOWER('%turbine%') OR LOWER(brand) LIKE LOWER('%turbine%')) THEN 'turbine' END, CASE WHEN (LOWER(name) LIKE LOWER('%engine%') OR LOWER(operator) LIKE LOWER('%engine%') OR LOWER(brand) LIKE LOWER('%engine%')) THEN 'engine' END, CASE WHEN (LOWER(name) LIKE LOWER('%precision%') OR LOWER(operator) LIKE LOWER('%precision%') OR LOWER(brand) LIKE LOWER('%precision%')) THEN 'precision' END, CASE WHEN (LOWER(name) LIKE LOWER('%machining%') OR LOWER(operator) LIKE LOWER('%machining%') OR LOWER(brand) LIKE LOWER('%machining%')) THEN 'machining' END, CASE WHEN (LOWER(name) LIKE LOWER('%casting%') OR LOWER(operator) LIKE LOWER('%casting%') OR LOWER(brand) LIKE LOWER('%casting%')) THEN 'casting' END, CASE WHEN (LOWER(name) LIKE LOWER('%forging%') OR LOWER(operator) LIKE LOWER('%forging%') OR LOWER(brand) LIKE LOWER('%forging%')) THEN 'forging' END, CASE WHEN (LOWER(name) LIKE LOWER('%composite%') OR LOWER(operator) LIKE LOWER('%composite%') OR LOWER(brand) LIKE LOWER('%composite%')) THEN 'composite' END, CASE WHEN (LOWER(name) LIKE LOWER('%materials%') OR LOWER(operator) LIKE LOWER('%materials%') OR LOWER(brand) LIKE LOWER('%materials%')) THEN 'materials' END, CASE WHEN (LOWER(name) LIKE LOWER('%engineering%') OR LOWER(operator) LIKE LOWER('%engineering%') OR LOWER(brand) LIKE LOWER('%engineering%')) THEN 'engineering' END, CASE WHEN (LOWER(name) LIKE LOWER('%technology%') OR LOWER(operator) LIKE LOWER('%technology%') OR LOWER(brand) LIKE LOWER('%technology%')) THEN 'technology' END, CASE WHEN (LOWER(name) LIKE LOWER('%systems%') OR LOWER(operator) LIKE LOWER('%systems%') OR LOWER(brand) LIKE LOWER('%systems%')) THEN 'systems' END, CASE WHEN (LOWER(name) LIKE LOWER('%electronics%') OR LOWER(operator) LIKE LOWER('%electronics%') OR LOWER(brand) LIKE LOWER('%electronics%')) THEN 'electronics' END, CASE WHEN (LOWER(name) LIKE LOWER('%software%') OR LOWER(operator) LIKE LOWER('%software%') OR LOWER(brand) LIKE LOWER('%software%')) THEN 'software' END, CASE WHEN (LOWER(name) LIKE LOWER('%control%') OR LOWER(operator) LIKE LOWER('%control%') OR LOWER(brand) LIKE LOWER('%control%')) THEN 'control' END], NULL) AS matched_keywords,
    'planet_osm_roads' AS source_table
FROM public.planet_osm_roads_aerospace_filtered
WHERE aerospace_score > 0;

-- STEP 4: Insert results into final table
-- Insert aerospace supplier candidates
INSERT INTO aerospace_supplier_candidates (osm_id, osm_type, name, operator, website, phone, email, postcode, street_address, city, county, landuse_type, building_type, industrial_type, office_type, description, brand, geometry, centroid, area_sqm, latitude, longitude, aerospace_score, matched_keywords, tier_classification, confidence_level, created_at, data_source, processing_notes)
SELECT
    osm_id AS osm_id,
    table_name AS osm_type,
    COALESCE(name, operator, brand, company) AS name,
    operator AS operator,
    COALESCE(website, contact_website, url) AS website,
    COALESCE(phone, contact_phone, telephone) AS phone,
    COALESCE(email, contact_email) AS email,
    addr_postcode AS postcode,
    addr_street AS street_address,
    COALESCE(addr_city, addr_town, place) AS city,
    COALESCE(addr_county, addr_state, addr_region) AS county,
    landuse AS landuse_type,
    building AS building_type,
    COALESCE(industrial, craft, manufacturing) AS industrial_type,
    office AS office_type,
    description AS description,
    brand AS brand,
    way AS geometry,
    ST_Centroid(way) AS centroid,
    ST_Area(way) AS area_sqm,
    ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude,
    aerospace_score,
    matched_keywords,
    CASE
    WHEN aerospace_score >= 150 THEN 'tier1_candidate'
    WHEN aerospace_score BETWEEN 80 AND 149 THEN 'tier2_candidate'
    WHEN aerospace_score BETWEEN 40 AND 79 THEN 'potential_candidate'
    WHEN aerospace_score BETWEEN 10 AND 39 THEN 'low_probability'
    WHEN aerospace_score <= 9 THEN 'excluded'
    ELSE 'unclassified'
END AS tier_classification,
    CASE
    WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
    WHEN aerospace_score >= 80 THEN 'medium'
    WHEN aerospace_score >= 40 THEN 'low'
    ELSE 'very_low'
END AS confidence_level,
    NOW() AS created_at,
    'UK OSM' AS data_source,
    CASE WHEN aerospace_score >= 150 THEN 'High confidence' WHEN aerospace_score >= 80 THEN 'Strong candidate' WHEN aerospace_score >= 40 THEN 'Potential' ELSE 'Low probability' END AS processing_notes
FROM public.planet_osm_point_aerospace_scoredUNION ALL
SELECT
    osm_id AS osm_id,
    table_name AS osm_type,
    COALESCE(name, operator, brand, company) AS name,
    operator AS operator,
    COALESCE(website, contact_website, url) AS website,
    COALESCE(phone, contact_phone, telephone) AS phone,
    COALESCE(email, contact_email) AS email,
    addr_postcode AS postcode,
    addr_street AS street_address,
    COALESCE(addr_city, addr_town, place) AS city,
    COALESCE(addr_county, addr_state, addr_region) AS county,
    landuse AS landuse_type,
    building AS building_type,
    COALESCE(industrial, craft, manufacturing) AS industrial_type,
    office AS office_type,
    description AS description,
    brand AS brand,
    way AS geometry,
    ST_Centroid(way) AS centroid,
    ST_Area(way) AS area_sqm,
    ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude,
    aerospace_score,
    matched_keywords,
    CASE
    WHEN aerospace_score >= 150 THEN 'tier1_candidate'
    WHEN aerospace_score BETWEEN 80 AND 149 THEN 'tier2_candidate'
    WHEN aerospace_score BETWEEN 40 AND 79 THEN 'potential_candidate'
    WHEN aerospace_score BETWEEN 10 AND 39 THEN 'low_probability'
    WHEN aerospace_score <= 9 THEN 'excluded'
    ELSE 'unclassified'
END AS tier_classification,
    CASE
    WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
    WHEN aerospace_score >= 80 THEN 'medium'
    WHEN aerospace_score >= 40 THEN 'low'
    ELSE 'very_low'
END AS confidence_level,
    NOW() AS created_at,
    'UK OSM' AS data_source,
    CASE WHEN aerospace_score >= 150 THEN 'High confidence' WHEN aerospace_score >= 80 THEN 'Strong candidate' WHEN aerospace_score >= 40 THEN 'Potential' ELSE 'Low probability' END AS processing_notes
FROM public.planet_osm_line_aerospace_scoredUNION ALL
SELECT
    osm_id AS osm_id,
    table_name AS osm_type,
    COALESCE(name, operator, brand, company) AS name,
    operator AS operator,
    COALESCE(website, contact_website, url) AS website,
    COALESCE(phone, contact_phone, telephone) AS phone,
    COALESCE(email, contact_email) AS email,
    addr_postcode AS postcode,
    addr_street AS street_address,
    COALESCE(addr_city, addr_town, place) AS city,
    COALESCE(addr_county, addr_state, addr_region) AS county,
    landuse AS landuse_type,
    building AS building_type,
    COALESCE(industrial, craft, manufacturing) AS industrial_type,
    office AS office_type,
    description AS description,
    brand AS brand,
    way AS geometry,
    ST_Centroid(way) AS centroid,
    ST_Area(way) AS area_sqm,
    ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude,
    aerospace_score,
    matched_keywords,
    CASE
    WHEN aerospace_score >= 150 THEN 'tier1_candidate'
    WHEN aerospace_score BETWEEN 80 AND 149 THEN 'tier2_candidate'
    WHEN aerospace_score BETWEEN 40 AND 79 THEN 'potential_candidate'
    WHEN aerospace_score BETWEEN 10 AND 39 THEN 'low_probability'
    WHEN aerospace_score <= 9 THEN 'excluded'
    ELSE 'unclassified'
END AS tier_classification,
    CASE
    WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
    WHEN aerospace_score >= 80 THEN 'medium'
    WHEN aerospace_score >= 40 THEN 'low'
    ELSE 'very_low'
END AS confidence_level,
    NOW() AS created_at,
    'UK OSM' AS data_source,
    CASE WHEN aerospace_score >= 150 THEN 'High confidence' WHEN aerospace_score >= 80 THEN 'Strong candidate' WHEN aerospace_score >= 40 THEN 'Potential' ELSE 'Low probability' END AS processing_notes
FROM public.planet_osm_polygon_aerospace_scoredUNION ALL
SELECT
    osm_id AS osm_id,
    table_name AS osm_type,
    COALESCE(name, operator, brand, company) AS name,
    operator AS operator,
    COALESCE(website, contact_website, url) AS website,
    COALESCE(phone, contact_phone, telephone) AS phone,
    COALESCE(email, contact_email) AS email,
    addr_postcode AS postcode,
    addr_street AS street_address,
    COALESCE(addr_city, addr_town, place) AS city,
    COALESCE(addr_county, addr_state, addr_region) AS county,
    landuse AS landuse_type,
    building AS building_type,
    COALESCE(industrial, craft, manufacturing) AS industrial_type,
    office AS office_type,
    description AS description,
    brand AS brand,
    way AS geometry,
    ST_Centroid(way) AS centroid,
    ST_Area(way) AS area_sqm,
    ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude,
    aerospace_score,
    matched_keywords,
    CASE
    WHEN aerospace_score >= 150 THEN 'tier1_candidate'
    WHEN aerospace_score BETWEEN 80 AND 149 THEN 'tier2_candidate'
    WHEN aerospace_score BETWEEN 40 AND 79 THEN 'potential_candidate'
    WHEN aerospace_score BETWEEN 10 AND 39 THEN 'low_probability'
    WHEN aerospace_score <= 9 THEN 'excluded'
    ELSE 'unclassified'
END AS tier_classification,
    CASE
    WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
    WHEN aerospace_score >= 80 THEN 'medium'
    WHEN aerospace_score >= 40 THEN 'low'
    ELSE 'very_low'
END AS confidence_level,
    NOW() AS created_at,
    'UK OSM' AS data_source,
    CASE WHEN aerospace_score >= 150 THEN 'High confidence' WHEN aerospace_score >= 80 THEN 'Strong candidate' WHEN aerospace_score >= 40 THEN 'Potential' ELSE 'Low probability' END AS processing_notes
FROM public.planet_osm_roads_aerospace_scored
WHERE aerospace_score >= 0
ORDER BY aerospace_score DESC
LIMIT 5000;
