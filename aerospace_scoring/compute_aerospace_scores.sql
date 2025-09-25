-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM

-- Generated on: 2025-09-25 16:16:31

-- STEP 1: Exclusion Filters
-- Minimal Aerospace Exclusion Filters
-- Creates pass-through views with minimal filtering

-- Filtered view for planet_osm_point
DROP VIEW IF EXISTS public.planet_osm_point_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_point_aerospace_filtered AS
SELECT * FROM public.planet_osm_point
WHERE (amenity IS NULL OR amenity NOT IN ('restaurant', 'cafe', 'pub', 'fast_food'));

-- Filtered view for planet_osm_line
DROP VIEW IF EXISTS public.planet_osm_line_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_line_aerospace_filtered AS
SELECT * FROM public.planet_osm_line
WHERE 1=1;

-- Filtered view for planet_osm_polygon
DROP VIEW IF EXISTS public.planet_osm_polygon_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_polygon_aerospace_filtered AS
SELECT * FROM public.planet_osm_polygon
WHERE 1=1;

-- Filtered view for planet_osm_roads
DROP VIEW IF EXISTS public.planet_osm_roads_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_roads_aerospace_filtered AS
SELECT * FROM public.planet_osm_roads
WHERE 1=1;


-- STEP 2: Scoring Rules
-- Aerospace Supplier Scoring SQL
-- Generated from scoring.yaml and negative_signals.yaml

-- Scored view for planet_osm_point
DROP VIEW IF EXISTS public.planet_osm_point_aerospace_scored CASCADE;
CREATE VIEW public.planet_osm_point_aerospace_scored AS
SELECT *,
    (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_point' AS source_table
FROM public.planet_osm_point_aerospace_filtered
WHERE (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) > 0;

-- Scored view for planet_osm_line
DROP VIEW IF EXISTS public.planet_osm_line_aerospace_scored CASCADE;
CREATE VIEW public.planet_osm_line_aerospace_scored AS
SELECT *,
    (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_line' AS source_table
FROM public.planet_osm_line_aerospace_filtered
WHERE (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) > 0;

-- Scored view for planet_osm_polygon
DROP VIEW IF EXISTS public.planet_osm_polygon_aerospace_scored CASCADE;
CREATE VIEW public.planet_osm_polygon_aerospace_scored AS
SELECT *,
    (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_polygon' AS source_table
FROM public.planet_osm_polygon_aerospace_filtered
WHERE (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) > 0;

-- Scored view for planet_osm_roads
DROP VIEW IF EXISTS public.planet_osm_roads_aerospace_scored CASCADE;
CREATE VIEW public.planet_osm_roads_aerospace_scored AS
SELECT *,
    (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) AS aerospace_score,
    ARRAY[]::text[] AS matched_keywords,
    'planet_osm_roads' AS source_table
FROM public.planet_osm_roads_aerospace_filtered
WHERE (CASE WHEN (name ILIKE '%aerospace%' OR name ILIKE '%aviation%' OR name ILIKE '%aircraft%' OR name ILIKE '%airbus%' OR name ILIKE '%boeing%' OR name ILIKE '%bae%' OR name ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN (operator ILIKE '%aerospace%' OR operator ILIKE '%aviation%' OR operator ILIKE '%aircraft%' OR operator ILIKE '%airbus%' OR operator ILIKE '%boeing%' OR operator ILIKE '%bae%' OR operator ILIKE '%rolls royce%') THEN 100 ELSE 0 END + CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END + CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END + CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END + CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END + CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END + CASE WHEN (name ILIKE '%technology%' OR name ILIKE '%engineering%' OR name ILIKE '%systems%' OR name ILIKE '%electronics%' OR name ILIKE '%precision%') THEN 35 ELSE 0 END) > 0;


-- STEP 3: Create output table
DROP TABLE IF EXISTS public.aerospace_supplier_candidates CASCADE;
CREATE TABLE public.aerospace_supplier_candidates (
  osm_id BIGINT,
  osm_type VARCHAR(50),
  name TEXT,
  operator TEXT,
  website TEXT,
  landuse_type TEXT,
  geometry GEOMETRY,
  aerospace_score INTEGER,
  tier_classification VARCHAR(50),
  matched_keywords TEXT[],
  source_table VARCHAR(50),
  created_at TIMESTAMP
);
CREATE INDEX ON public.aerospace_supplier_candidates(aerospace_score);
CREATE INDEX ON public.aerospace_supplier_candidates(tier_classification);
CREATE INDEX ON public.aerospace_supplier_candidates USING GIST(geometry);


-- STEP 4: Insert final results
INSERT INTO public.aerospace_supplier_candidates (osm_id, osm_type, name, operator, website, landuse_type, geometry, aerospace_score, tier_classification, matched_keywords, source_table, created_at)
SELECT
  osm_id,
  'point' AS osm_type,
  COALESCE(name,operator) AS name,
  operator,
  website,
  landuse AS landuse_type,
  way AS geometry,
  aerospace_score,
  CASE
    WHEN aerospace_score>=150 THEN 'tier1_candidate'
    WHEN aerospace_score>=80  THEN 'tier2_candidate'
    WHEN aerospace_score>=40  THEN 'potential_candidate'
    WHEN aerospace_score>=10  THEN 'low_probability'
    ELSE 'excluded'
  END AS tier_classification,
  matched_keywords,
  source_table,
  NOW() AS created_at
FROM public.planet_osm_point_aerospace_scored
WHERE aerospace_score >= 10
UNION ALL
SELECT
  osm_id,
  'polygon' AS osm_type,
  COALESCE(name,operator) AS name,
  operator,
  website,
  landuse AS landuse_type,
  way AS geometry,
  aerospace_score,
  CASE
    WHEN aerospace_score>=150 THEN 'tier1_candidate'
    WHEN aerospace_score>=80  THEN 'tier2_candidate'
    WHEN aerospace_score>=40  THEN 'potential_candidate'
    WHEN aerospace_score>=10  THEN 'low_probability'
    ELSE 'excluded'
  END AS tier_classification,
  matched_keywords,
  source_table,
  NOW() AS created_at
FROM public.planet_osm_polygon_aerospace_scored
WHERE aerospace_score >= 10
UNION ALL
SELECT
  osm_id,
  'line' AS osm_type,
  COALESCE(name,operator) AS name,
  operator,
  website,
  landuse AS landuse_type,
  way AS geometry,
  aerospace_score,
  CASE
    WHEN aerospace_score>=150 THEN 'tier1_candidate'
    WHEN aerospace_score>=80  THEN 'tier2_candidate'
    WHEN aerospace_score>=40  THEN 'potential_candidate'
    WHEN aerospace_score>=10  THEN 'low_probability'
    ELSE 'excluded'
  END AS tier_classification,
  matched_keywords,
  source_table,
  NOW() AS created_at
FROM public.planet_osm_line_aerospace_scored
WHERE aerospace_score >= 10
ON CONFLICT DO NOTHING;


-- STEP 5: Analysis queries

SELECT 'Total candidates' AS metric, COUNT(*) AS value FROM public.aerospace_supplier_candidates;

SELECT tier_classification, COUNT(*) AS cnt FROM public.aerospace_supplier_candidates GROUP BY tier_classification ORDER BY cnt DESC;