-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM
-- Generated on: 2025-10-01 09:12:44
-- Schema: public

-- STEP 1: Apply exclusion filters
-- Aerospace Supplier Exclusion Filters
-- Generated from exclusions.yaml for schema: public
-- Auto-detected actual schema from database

-- Filtered view for planet_osm_point
DROP VIEW IF EXISTS public.planet_osm_point_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_point_aerospace_filtered AS
SELECT * FROM public.planet_osm_point
WHERE ((("landuse" IS NULL OR "landuse" NOT IN ('residential', 'retail', 'commercial')) AND ("amenity" IS NULL OR "amenity" NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy')) AND "shop" IS NULL AND "tourism" IS NULL AND ("leisure" IS NULL OR "leisure" NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course')) AND ("railway" IS NULL OR "railway" NOT IN ('station', 'halt', 'platform')) AND ("natural" IS NULL OR "natural" NOT IN ('forest', 'water', 'wood', 'grassland', 'scrub')) AND ("barrier" IS NULL OR "barrier" NOT IN ('fence', 'wall', 'hedge')) AND ("landuse" IS NULL OR "landuse" NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill')) AND ("man_made" IS NULL OR "man_made" NOT IN ('water_tower', 'water_works', 'sewage_plant')) AND ("amenity" IS NULL OR "amenity" NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'parking')) AND "shop" IS NULL AND "tourism" IS NULL) OR ((LOWER("name") LIKE LOWER('%aerospace%') OR LOWER("name") LIKE LOWER('%aviation%') OR LOWER("name") LIKE LOWER('%aircraft%') OR LOWER("name") LIKE LOWER('%airbus%') OR LOWER("name") LIKE LOWER('%boeing%') OR LOWER("name") LIKE LOWER('%rolls royce%') OR LOWER("name") LIKE LOWER('%bae systems%')) OR (LOWER("operator") LIKE LOWER('%aerospace%') OR LOWER("operator") LIKE LOWER('%aviation%') OR LOWER("operator") LIKE LOWER('%aircraft%')) OR "landuse" IN ('industrial') OR "man_made" IN ('works', 'factory') OR "office" IN ('company', 'research', 'engineering')));
-- Row count check:
-- SELECT COUNT(*) FROM public.planet_osm_point_aerospace_filtered;

-- Filtered view for planet_osm_line
DROP VIEW IF EXISTS public.planet_osm_line_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_line_aerospace_filtered AS
SELECT * FROM public.planet_osm_line
WHERE ((("landuse" IS NULL OR "landuse" NOT IN ('residential', 'retail', 'commercial')) AND ("building" IS NULL OR "building" NOT IN ('house', 'apartments', 'residential', 'hotel', 'retail', 'supermarket')) AND ("amenity" IS NULL OR "amenity" NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy')) AND "shop" IS NULL AND "tourism" IS NULL AND ("leisure" IS NULL OR "leisure" NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course')) AND ("railway" IS NULL OR "railway" NOT IN ('station', 'halt', 'platform')) AND ("natural" IS NULL OR "natural" NOT IN ('forest', 'water', 'wood', 'grassland', 'scrub')) AND ("barrier" IS NULL OR "barrier" NOT IN ('fence', 'wall', 'hedge')) AND ("landuse" IS NULL OR "landuse" NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill')) AND ("man_made" IS NULL OR "man_made" NOT IN ('water_tower', 'water_works', 'sewage_plant')) AND ("highway" IS NULL OR "highway" NOT IN ('footway', 'cycleway', 'path', 'steps')) AND ("railway" IS NULL OR "railway" NOT IN ('abandoned', 'disused'))) OR ((LOWER("name") LIKE LOWER('%aerospace%') OR LOWER("name") LIKE LOWER('%aviation%') OR LOWER("name") LIKE LOWER('%aircraft%') OR LOWER("name") LIKE LOWER('%airbus%') OR LOWER("name") LIKE LOWER('%boeing%') OR LOWER("name") LIKE LOWER('%rolls royce%') OR LOWER("name") LIKE LOWER('%bae systems%')) OR (LOWER("operator") LIKE LOWER('%aerospace%') OR LOWER("operator") LIKE LOWER('%aviation%') OR LOWER("operator") LIKE LOWER('%aircraft%')) OR "landuse" IN ('industrial') OR "building" IN ('industrial', 'warehouse', 'factory', 'manufacture') OR "man_made" IN ('works', 'factory') OR "industrial" IS NOT NULL OR "office" IN ('company', 'research', 'engineering')));
-- Row count check:
-- SELECT COUNT(*) FROM public.planet_osm_line_aerospace_filtered;

-- Filtered view for planet_osm_polygon
DROP VIEW IF EXISTS public.planet_osm_polygon_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_polygon_aerospace_filtered AS
SELECT * FROM public.planet_osm_polygon
WHERE ((("landuse" IS NULL OR "landuse" NOT IN ('residential', 'retail', 'commercial')) AND ("building" IS NULL OR "building" NOT IN ('house', 'apartments', 'residential', 'hotel', 'retail', 'supermarket')) AND ("amenity" IS NULL OR "amenity" NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy')) AND "shop" IS NULL AND "tourism" IS NULL AND ("leisure" IS NULL OR "leisure" NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course')) AND ("railway" IS NULL OR "railway" NOT IN ('station', 'halt', 'platform')) AND ("natural" IS NULL OR "natural" NOT IN ('forest', 'water', 'wood', 'grassland', 'scrub')) AND ("barrier" IS NULL OR "barrier" NOT IN ('fence', 'wall', 'hedge')) AND ("landuse" IS NULL OR "landuse" NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill')) AND ("man_made" IS NULL OR "man_made" NOT IN ('water_tower', 'water_works', 'sewage_plant')) AND ("building" IS NULL OR "building" NOT IN ('house', 'apartments', 'residential')) AND ("landuse" IS NULL OR "landuse" NOT IN ('residential', 'farmland', 'forest'))) OR ((LOWER("name") LIKE LOWER('%aerospace%') OR LOWER("name") LIKE LOWER('%aviation%') OR LOWER("name") LIKE LOWER('%aircraft%') OR LOWER("name") LIKE LOWER('%airbus%') OR LOWER("name") LIKE LOWER('%boeing%') OR LOWER("name") LIKE LOWER('%rolls royce%') OR LOWER("name") LIKE LOWER('%bae systems%')) OR (LOWER("operator") LIKE LOWER('%aerospace%') OR LOWER("operator") LIKE LOWER('%aviation%') OR LOWER("operator") LIKE LOWER('%aircraft%')) OR "landuse" IN ('industrial') OR "building" IN ('industrial', 'warehouse', 'factory', 'manufacture') OR "man_made" IN ('works', 'factory') OR "industrial" IS NOT NULL OR "office" IN ('company', 'research', 'engineering')));
-- Row count check:
-- SELECT COUNT(*) FROM public.planet_osm_polygon_aerospace_filtered;

-- Filtered view for planet_osm_roads
DROP VIEW IF EXISTS public.planet_osm_roads_aerospace_filtered CASCADE;
CREATE VIEW public.planet_osm_roads_aerospace_filtered AS
SELECT * FROM public.planet_osm_roads
WHERE ((("landuse" IS NULL OR "landuse" NOT IN ('residential', 'retail', 'commercial')) AND ("building" IS NULL OR "building" NOT IN ('house', 'apartments', 'residential', 'hotel', 'retail', 'supermarket')) AND ("amenity" IS NULL OR "amenity" NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy')) AND "shop" IS NULL AND "tourism" IS NULL AND ("leisure" IS NULL OR "leisure" NOT IN ('park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course')) AND ("railway" IS NULL OR "railway" NOT IN ('station', 'halt', 'platform')) AND ("natural" IS NULL OR "natural" NOT IN ('forest', 'water', 'wood', 'grassland', 'scrub')) AND ("barrier" IS NULL OR "barrier" NOT IN ('fence', 'wall', 'hedge')) AND ("landuse" IS NULL OR "landuse" NOT IN ('farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill')) AND ("man_made" IS NULL OR "man_made" NOT IN ('water_tower', 'water_works', 'sewage_plant'))) OR ((LOWER("name") LIKE LOWER('%aerospace%') OR LOWER("name") LIKE LOWER('%aviation%') OR LOWER("name") LIKE LOWER('%aircraft%') OR LOWER("name") LIKE LOWER('%airbus%') OR LOWER("name") LIKE LOWER('%boeing%') OR LOWER("name") LIKE LOWER('%rolls royce%') OR LOWER("name") LIKE LOWER('%bae systems%')) OR (LOWER("operator") LIKE LOWER('%aerospace%') OR LOWER("operator") LIKE LOWER('%aviation%') OR LOWER("operator") LIKE LOWER('%aircraft%')) OR "landuse" IN ('industrial') OR "building" IN ('industrial', 'warehouse', 'factory', 'manufacture') OR "man_made" IN ('works', 'factory') OR "industrial" IS NOT NULL OR "office" IN ('company', 'research', 'engineering')));
-- Row count check:
-- SELECT COUNT(*) FROM public.planet_osm_roads_aerospace_filtered;


-- STEP 2: Apply scoring rules
-- Aerospace Supplier Scoring SQL
-- Generated: 2025-10-01T08:12:44.397856
-- Schema: public

-- Scored view for planet_osm_point
CREATE OR REPLACE VIEW public.planet_osm_point_aerospace_scored AS
SELECT
  source.*,
  (
    CASE
    WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%bae%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%safran%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%')) OR source."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(source."name") LIKE LOWER('%defense%') OR LOWER(source."name") LIKE LOWER('%defence%') OR LOWER(source."name") LIKE LOWER('%military%') OR LOWER(source."name") LIKE LOWER('%radar%') OR LOWER(source."name") LIKE LOWER('%missile%') OR LOWER(source."name") LIKE LOWER('%weapons%')) OR source."military" IS NOT NULL OR source."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(source."name") LIKE LOWER('%engineering%') OR LOWER(source."name") LIKE LOWER('%technology%') OR LOWER(source."name") LIKE LOWER('%systems%') OR LOWER(source."name") LIKE LOWER('%electronics%') OR LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%advanced%')) OR source."man_made" IN ('works','factory') OR source."office" IN ('engineering','research','technology')) THEN 70
    WHEN (source."landuse" IN ('industrial')) THEN 50
    WHEN ((LOWER(source."name") LIKE LOWER('%research%') OR LOWER(source."name") LIKE LOWER('%development%') OR LOWER(source."name") LIKE LOWER('%laboratory%') OR LOWER(source."name") LIKE LOWER('%institute%') OR LOWER(source."name") LIKE LOWER('%university%')) OR source."office" IN ('research','engineering') OR source."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%bae systems%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%') OR LOWER(source."name") LIKE LOWER('%safran%')) OR (LOWER(source."operator") LIKE LOWER('%boeing%') OR LOWER(source."operator") LIKE LOWER('%airbus%') OR LOWER(source."operator") LIKE LOWER('%rolls royce%') OR LOWER(source."operator") LIKE LOWER('%bae systems%') OR LOWER(source."operator") LIKE LOWER('%leonardo%') OR LOWER(source."operator") LIKE LOWER('%thales%') OR LOWER(source."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%avionics%') OR LOWER(source."name") LIKE LOWER('%turbine%') OR LOWER(source."name") LIKE LOWER('%engine%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%') OR LOWER(source."operator") LIKE LOWER('%avionics%') OR LOWER(source."operator") LIKE LOWER('%turbine%') OR LOWER(source."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%machining%') OR LOWER(source."name") LIKE LOWER('%casting%') OR LOWER(source."name") LIKE LOWER('%forging%') OR LOWER(source."name") LIKE LOWER('%composite%') OR LOWER(source."name") LIKE LOWER('%materials%')) OR (LOWER(source."operator") LIKE LOWER('%precision%') OR LOWER(source."operator") LIKE LOWER('%machining%') OR LOWER(source."operator") LIKE LOWER('%casting%') OR LOWER(source."operator") LIKE LOWER('%forging%') OR LOWER(source."operator") LIKE LOWER('%composite%') OR LOWER(source."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (source."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR source."shop" IS NOT NULL OR source."tourism" IS NOT NULL OR source."leisure" IS NOT NULL) THEN -50 ELSE 0 END +
    CASE WHEN (source."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (source."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR source."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) AS aerospace_score,
  ARRAY[]::text[] AS matched_keywords,
  'planet_osm_point' AS source_table
FROM public.planet_osm_point_aerospace_filtered filtered
JOIN public.planet_osm_point source ON filtered.osm_id = source.osm_id
WHERE
  (
    CASE
    WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%bae%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%safran%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%')) OR source."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(source."name") LIKE LOWER('%defense%') OR LOWER(source."name") LIKE LOWER('%defence%') OR LOWER(source."name") LIKE LOWER('%military%') OR LOWER(source."name") LIKE LOWER('%radar%') OR LOWER(source."name") LIKE LOWER('%missile%') OR LOWER(source."name") LIKE LOWER('%weapons%')) OR source."military" IS NOT NULL OR source."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(source."name") LIKE LOWER('%engineering%') OR LOWER(source."name") LIKE LOWER('%technology%') OR LOWER(source."name") LIKE LOWER('%systems%') OR LOWER(source."name") LIKE LOWER('%electronics%') OR LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%advanced%')) OR source."man_made" IN ('works','factory') OR source."office" IN ('engineering','research','technology')) THEN 70
    WHEN (source."landuse" IN ('industrial')) THEN 50
    WHEN ((LOWER(source."name") LIKE LOWER('%research%') OR LOWER(source."name") LIKE LOWER('%development%') OR LOWER(source."name") LIKE LOWER('%laboratory%') OR LOWER(source."name") LIKE LOWER('%institute%') OR LOWER(source."name") LIKE LOWER('%university%')) OR source."office" IN ('research','engineering') OR source."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%bae systems%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%') OR LOWER(source."name") LIKE LOWER('%safran%')) OR (LOWER(source."operator") LIKE LOWER('%boeing%') OR LOWER(source."operator") LIKE LOWER('%airbus%') OR LOWER(source."operator") LIKE LOWER('%rolls royce%') OR LOWER(source."operator") LIKE LOWER('%bae systems%') OR LOWER(source."operator") LIKE LOWER('%leonardo%') OR LOWER(source."operator") LIKE LOWER('%thales%') OR LOWER(source."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%avionics%') OR LOWER(source."name") LIKE LOWER('%turbine%') OR LOWER(source."name") LIKE LOWER('%engine%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%') OR LOWER(source."operator") LIKE LOWER('%avionics%') OR LOWER(source."operator") LIKE LOWER('%turbine%') OR LOWER(source."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%machining%') OR LOWER(source."name") LIKE LOWER('%casting%') OR LOWER(source."name") LIKE LOWER('%forging%') OR LOWER(source."name") LIKE LOWER('%composite%') OR LOWER(source."name") LIKE LOWER('%materials%')) OR (LOWER(source."operator") LIKE LOWER('%precision%') OR LOWER(source."operator") LIKE LOWER('%machining%') OR LOWER(source."operator") LIKE LOWER('%casting%') OR LOWER(source."operator") LIKE LOWER('%forging%') OR LOWER(source."operator") LIKE LOWER('%composite%') OR LOWER(source."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (source."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR source."shop" IS NOT NULL OR source."tourism" IS NOT NULL OR source."leisure" IS NOT NULL) THEN -50 ELSE 0 END +
    CASE WHEN (source."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (source."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR source."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) > 0;

-- Scored view for planet_osm_line
CREATE OR REPLACE VIEW public.planet_osm_line_aerospace_scored AS
SELECT
  source.*,
  (
    CASE
    WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%bae%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%safran%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%')) OR source."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(source."name") LIKE LOWER('%defense%') OR LOWER(source."name") LIKE LOWER('%defence%') OR LOWER(source."name") LIKE LOWER('%military%') OR LOWER(source."name") LIKE LOWER('%radar%') OR LOWER(source."name") LIKE LOWER('%missile%') OR LOWER(source."name") LIKE LOWER('%weapons%')) OR source."military" IS NOT NULL OR source."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(source."name") LIKE LOWER('%engineering%') OR LOWER(source."name") LIKE LOWER('%technology%') OR LOWER(source."name") LIKE LOWER('%systems%') OR LOWER(source."name") LIKE LOWER('%electronics%') OR LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%advanced%')) OR source."industrial" IN ('engineering','electronics','precision','high_tech') OR source."man_made" IN ('works','factory') OR source."office" IN ('engineering','research','technology') OR source."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (source."landuse" IN ('industrial') OR source."building" IN ('industrial','warehouse','manufacture') OR source."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(source."name") LIKE LOWER('%research%') OR LOWER(source."name") LIKE LOWER('%development%') OR LOWER(source."name") LIKE LOWER('%laboratory%') OR LOWER(source."name") LIKE LOWER('%institute%') OR LOWER(source."name") LIKE LOWER('%university%')) OR source."office" IN ('research','engineering') OR source."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%bae systems%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%') OR LOWER(source."name") LIKE LOWER('%safran%')) OR (LOWER(source."operator") LIKE LOWER('%boeing%') OR LOWER(source."operator") LIKE LOWER('%airbus%') OR LOWER(source."operator") LIKE LOWER('%rolls royce%') OR LOWER(source."operator") LIKE LOWER('%bae systems%') OR LOWER(source."operator") LIKE LOWER('%leonardo%') OR LOWER(source."operator") LIKE LOWER('%thales%') OR LOWER(source."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%avionics%') OR LOWER(source."name") LIKE LOWER('%turbine%') OR LOWER(source."name") LIKE LOWER('%engine%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%') OR LOWER(source."operator") LIKE LOWER('%avionics%') OR LOWER(source."operator") LIKE LOWER('%turbine%') OR LOWER(source."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%machining%') OR LOWER(source."name") LIKE LOWER('%casting%') OR LOWER(source."name") LIKE LOWER('%forging%') OR LOWER(source."name") LIKE LOWER('%composite%') OR LOWER(source."name") LIKE LOWER('%materials%')) OR (LOWER(source."operator") LIKE LOWER('%precision%') OR LOWER(source."operator") LIKE LOWER('%machining%') OR LOWER(source."operator") LIKE LOWER('%casting%') OR LOWER(source."operator") LIKE LOWER('%forging%') OR LOWER(source."operator") LIKE LOWER('%composite%') OR LOWER(source."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (source."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR source."shop" IS NOT NULL OR source."tourism" IS NOT NULL OR source."leisure" IS NOT NULL OR source."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (source."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (source."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR source."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) AS aerospace_score,
  ARRAY[]::text[] AS matched_keywords,
  'planet_osm_line' AS source_table
FROM public.planet_osm_line_aerospace_filtered filtered
JOIN public.planet_osm_line source ON filtered.osm_id = source.osm_id
WHERE
  (
    CASE
    WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%bae%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%safran%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%')) OR source."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(source."name") LIKE LOWER('%defense%') OR LOWER(source."name") LIKE LOWER('%defence%') OR LOWER(source."name") LIKE LOWER('%military%') OR LOWER(source."name") LIKE LOWER('%radar%') OR LOWER(source."name") LIKE LOWER('%missile%') OR LOWER(source."name") LIKE LOWER('%weapons%')) OR source."military" IS NOT NULL OR source."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(source."name") LIKE LOWER('%engineering%') OR LOWER(source."name") LIKE LOWER('%technology%') OR LOWER(source."name") LIKE LOWER('%systems%') OR LOWER(source."name") LIKE LOWER('%electronics%') OR LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%advanced%')) OR source."industrial" IN ('engineering','electronics','precision','high_tech') OR source."man_made" IN ('works','factory') OR source."office" IN ('engineering','research','technology') OR source."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (source."landuse" IN ('industrial') OR source."building" IN ('industrial','warehouse','manufacture') OR source."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(source."name") LIKE LOWER('%research%') OR LOWER(source."name") LIKE LOWER('%development%') OR LOWER(source."name") LIKE LOWER('%laboratory%') OR LOWER(source."name") LIKE LOWER('%institute%') OR LOWER(source."name") LIKE LOWER('%university%')) OR source."office" IN ('research','engineering') OR source."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%bae systems%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%') OR LOWER(source."name") LIKE LOWER('%safran%')) OR (LOWER(source."operator") LIKE LOWER('%boeing%') OR LOWER(source."operator") LIKE LOWER('%airbus%') OR LOWER(source."operator") LIKE LOWER('%rolls royce%') OR LOWER(source."operator") LIKE LOWER('%bae systems%') OR LOWER(source."operator") LIKE LOWER('%leonardo%') OR LOWER(source."operator") LIKE LOWER('%thales%') OR LOWER(source."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%avionics%') OR LOWER(source."name") LIKE LOWER('%turbine%') OR LOWER(source."name") LIKE LOWER('%engine%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%') OR LOWER(source."operator") LIKE LOWER('%avionics%') OR LOWER(source."operator") LIKE LOWER('%turbine%') OR LOWER(source."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%machining%') OR LOWER(source."name") LIKE LOWER('%casting%') OR LOWER(source."name") LIKE LOWER('%forging%') OR LOWER(source."name") LIKE LOWER('%composite%') OR LOWER(source."name") LIKE LOWER('%materials%')) OR (LOWER(source."operator") LIKE LOWER('%precision%') OR LOWER(source."operator") LIKE LOWER('%machining%') OR LOWER(source."operator") LIKE LOWER('%casting%') OR LOWER(source."operator") LIKE LOWER('%forging%') OR LOWER(source."operator") LIKE LOWER('%composite%') OR LOWER(source."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (source."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR source."shop" IS NOT NULL OR source."tourism" IS NOT NULL OR source."leisure" IS NOT NULL OR source."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (source."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (source."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR source."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) > 0;

-- Scored view for planet_osm_polygon
CREATE OR REPLACE VIEW public.planet_osm_polygon_aerospace_scored AS
SELECT
  source.*,
  (
    CASE
    WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%bae%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%safran%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%')) OR source."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(source."name") LIKE LOWER('%defense%') OR LOWER(source."name") LIKE LOWER('%defence%') OR LOWER(source."name") LIKE LOWER('%military%') OR LOWER(source."name") LIKE LOWER('%radar%') OR LOWER(source."name") LIKE LOWER('%missile%') OR LOWER(source."name") LIKE LOWER('%weapons%')) OR source."military" IS NOT NULL OR source."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(source."name") LIKE LOWER('%engineering%') OR LOWER(source."name") LIKE LOWER('%technology%') OR LOWER(source."name") LIKE LOWER('%systems%') OR LOWER(source."name") LIKE LOWER('%electronics%') OR LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%advanced%')) OR source."industrial" IN ('engineering','electronics','precision','high_tech') OR source."man_made" IN ('works','factory') OR source."office" IN ('engineering','research','technology') OR source."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (source."landuse" IN ('industrial') OR source."building" IN ('industrial','warehouse','manufacture') OR source."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(source."name") LIKE LOWER('%research%') OR LOWER(source."name") LIKE LOWER('%development%') OR LOWER(source."name") LIKE LOWER('%laboratory%') OR LOWER(source."name") LIKE LOWER('%institute%') OR LOWER(source."name") LIKE LOWER('%university%')) OR source."office" IN ('research','engineering') OR source."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%bae systems%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%') OR LOWER(source."name") LIKE LOWER('%safran%')) OR (LOWER(source."operator") LIKE LOWER('%boeing%') OR LOWER(source."operator") LIKE LOWER('%airbus%') OR LOWER(source."operator") LIKE LOWER('%rolls royce%') OR LOWER(source."operator") LIKE LOWER('%bae systems%') OR LOWER(source."operator") LIKE LOWER('%leonardo%') OR LOWER(source."operator") LIKE LOWER('%thales%') OR LOWER(source."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%avionics%') OR LOWER(source."name") LIKE LOWER('%turbine%') OR LOWER(source."name") LIKE LOWER('%engine%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%') OR LOWER(source."operator") LIKE LOWER('%avionics%') OR LOWER(source."operator") LIKE LOWER('%turbine%') OR LOWER(source."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%machining%') OR LOWER(source."name") LIKE LOWER('%casting%') OR LOWER(source."name") LIKE LOWER('%forging%') OR LOWER(source."name") LIKE LOWER('%composite%') OR LOWER(source."name") LIKE LOWER('%materials%')) OR (LOWER(source."operator") LIKE LOWER('%precision%') OR LOWER(source."operator") LIKE LOWER('%machining%') OR LOWER(source."operator") LIKE LOWER('%casting%') OR LOWER(source."operator") LIKE LOWER('%forging%') OR LOWER(source."operator") LIKE LOWER('%composite%') OR LOWER(source."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (source."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR source."shop" IS NOT NULL OR source."tourism" IS NOT NULL OR source."leisure" IS NOT NULL OR source."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (source."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (source."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR source."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) AS aerospace_score,
  ARRAY[]::text[] AS matched_keywords,
  'planet_osm_polygon' AS source_table
FROM public.planet_osm_polygon_aerospace_filtered filtered
JOIN public.planet_osm_polygon source ON filtered.osm_id = source.osm_id
WHERE
  (
    CASE
    WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%bae%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%safran%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%')) OR source."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(source."name") LIKE LOWER('%defense%') OR LOWER(source."name") LIKE LOWER('%defence%') OR LOWER(source."name") LIKE LOWER('%military%') OR LOWER(source."name") LIKE LOWER('%radar%') OR LOWER(source."name") LIKE LOWER('%missile%') OR LOWER(source."name") LIKE LOWER('%weapons%')) OR source."military" IS NOT NULL OR source."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(source."name") LIKE LOWER('%engineering%') OR LOWER(source."name") LIKE LOWER('%technology%') OR LOWER(source."name") LIKE LOWER('%systems%') OR LOWER(source."name") LIKE LOWER('%electronics%') OR LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%advanced%')) OR source."industrial" IN ('engineering','electronics','precision','high_tech') OR source."man_made" IN ('works','factory') OR source."office" IN ('engineering','research','technology') OR source."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (source."landuse" IN ('industrial') OR source."building" IN ('industrial','warehouse','manufacture') OR source."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(source."name") LIKE LOWER('%research%') OR LOWER(source."name") LIKE LOWER('%development%') OR LOWER(source."name") LIKE LOWER('%laboratory%') OR LOWER(source."name") LIKE LOWER('%institute%') OR LOWER(source."name") LIKE LOWER('%university%')) OR source."office" IN ('research','engineering') OR source."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%boeing%') OR LOWER(source."name") LIKE LOWER('%airbus%') OR LOWER(source."name") LIKE LOWER('%rolls royce%') OR LOWER(source."name") LIKE LOWER('%bae systems%') OR LOWER(source."name") LIKE LOWER('%leonardo%') OR LOWER(source."name") LIKE LOWER('%thales%') OR LOWER(source."name") LIKE LOWER('%safran%')) OR (LOWER(source."operator") LIKE LOWER('%boeing%') OR LOWER(source."operator") LIKE LOWER('%airbus%') OR LOWER(source."operator") LIKE LOWER('%rolls royce%') OR LOWER(source."operator") LIKE LOWER('%bae systems%') OR LOWER(source."operator") LIKE LOWER('%leonardo%') OR LOWER(source."operator") LIKE LOWER('%thales%') OR LOWER(source."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%aerospace%') OR LOWER(source."name") LIKE LOWER('%aviation%') OR LOWER(source."name") LIKE LOWER('%aircraft%') OR LOWER(source."name") LIKE LOWER('%avionics%') OR LOWER(source."name") LIKE LOWER('%turbine%') OR LOWER(source."name") LIKE LOWER('%engine%')) OR (LOWER(source."operator") LIKE LOWER('%aerospace%') OR LOWER(source."operator") LIKE LOWER('%aviation%') OR LOWER(source."operator") LIKE LOWER('%aircraft%') OR LOWER(source."operator") LIKE LOWER('%avionics%') OR LOWER(source."operator") LIKE LOWER('%turbine%') OR LOWER(source."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(source."name") LIKE LOWER('%precision%') OR LOWER(source."name") LIKE LOWER('%machining%') OR LOWER(source."name") LIKE LOWER('%casting%') OR LOWER(source."name") LIKE LOWER('%forging%') OR LOWER(source."name") LIKE LOWER('%composite%') OR LOWER(source."name") LIKE LOWER('%materials%')) OR (LOWER(source."operator") LIKE LOWER('%precision%') OR LOWER(source."operator") LIKE LOWER('%machining%') OR LOWER(source."operator") LIKE LOWER('%casting%') OR LOWER(source."operator") LIKE LOWER('%forging%') OR LOWER(source."operator") LIKE LOWER('%composite%') OR LOWER(source."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (source."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR source."shop" IS NOT NULL OR source."tourism" IS NOT NULL OR source."leisure" IS NOT NULL OR source."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (source."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (source."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR source."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) > 0;


-- STEP 3: Create output table
-- Create aerospace supplier candidates table in public
DROP TABLE IF EXISTS public.aerospace_supplier_candidates CASCADE;
CREATE TABLE public.aerospace_supplier_candidates (
    osm_id bigint,
    osm_type varchar(50),
    name text,
    operator text,
    website text,
    phone text,
    postcode varchar(20),
    street_address text,
    city text,
    landuse_type text,
    building_type text,
    industrial_type text,
    office_type text,
    description text,
    geometry geometry,
    latitude double precision,
    longitude double precision,
    aerospace_score integer,
    tier_classification varchar(50),
    matched_keywords text[],
    confidence_level varchar(20),
    created_at timestamp,
    source_table varchar(50)
);

-- Indexes
CREATE INDEX idx_aerospace_supplier_candidates_score ON public.aerospace_supplier_candidates(aerospace_score);
CREATE INDEX idx_aerospace_supplier_candidates_tier ON public.aerospace_supplier_candidates(tier_classification);
CREATE INDEX idx_aerospace_supplier_candidates_postcode ON public.aerospace_supplier_candidates(postcode);
CREATE INDEX idx_aerospace_supplier_candidates_geom ON public.aerospace_supplier_candidates USING GIST(geometry);

-- STEP 4: Insert final results
-- Insert aerospace supplier candidates into public.aerospace_supplier_candidates
WITH candidate_keys AS (
  SELECT osm_id, aerospace_score, source_table FROM public.planet_osm_point_aerospace_scored
  UNION ALL
  SELECT osm_id, aerospace_score, source_table FROM public.planet_osm_line_aerospace_scored
  UNION ALL
  SELECT osm_id, aerospace_score, source_table FROM public.planet_osm_polygon_aerospace_scored
), unique_keys AS (
  SELECT osm_id, source_table, MAX(aerospace_score) AS aerospace_score
  FROM candidate_keys
  GROUP BY osm_id, source_table
)
INSERT INTO public.aerospace_supplier_candidates (osm_id, osm_type, name, operator, website, phone, postcode, street_address, city, landuse_type, building_type, industrial_type, office_type, description, geometry, latitude, longitude, aerospace_score, tier_classification, matched_keywords, confidence_level, created_at, source_table)
SELECT
  k.osm_id,
  k.source_table AS osm_type,
  COALESCE(p.name, l.name, g.name) AS name,
  COALESCE(p.operator, l.operator, g.operator) AS operator,
  COALESCE(p.website, l.website, g.website) AS website,
  COALESCE(p.tags->'phone', p.tags->'contact:phone', l.tags->'phone', l.tags->'contact:phone', g.tags->'phone', g.tags->'contact:phone') AS phone,
  COALESCE(p.postcode, l.postcode, g.postcode) AS postcode,
  COALESCE(p.street_address, l.street_address, g.street_address) AS street_address,
  COALESCE(p.city, l.city, g.city) AS city,
  COALESCE(p.landuse_type, l.landuse_type, g.landuse_type) AS landuse_type,
  COALESCE(p.building_type, l.building_type, g.building_type) AS building_type,
  COALESCE(p.industrial_type, l.industrial_type, g.industrial_type) AS industrial_type,
  COALESCE(p.office_type, l.office_type, g.office_type) AS office_type,
  COALESCE(p.description, l.description, g.description) AS description,
  COALESCE(p.geometry, l.geometry, g.geometry) AS geometry,
  COALESCE(p.latitude, l.latitude, g.latitude) AS latitude,
  COALESCE(p.longitude, l.longitude, g.longitude) AS longitude,
  k.aerospace_score,
  CASE
        WHEN aerospace_score >= 150 THEN 'tier1_candidate'
        WHEN aerospace_score >= 80 THEN 'tier2_candidate'
        WHEN aerospace_score >= 40 THEN 'potential_candidate'
        WHEN aerospace_score >= 10 THEN 'low_probability'
        ELSE 'excluded'
    END AS tier_classification,
  COALESCE(p.matched_keywords, l.matched_keywords, g.matched_keywords) AS matched_keywords,
  CASE
        WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
        WHEN aerospace_score >= 80 THEN 'medium'
        WHEN aerospace_score >= 40 THEN 'low'
        ELSE 'very_low'
    END AS confidence_level,
  NOW() AS created_at,
  COALESCE(p.source_table, l.source_table, g.source_table) AS source_table
FROM unique_keys k
LEFT JOIN public.planet_osm_point_aerospace_scored   p ON k.osm_id = p.osm_id AND k.source_table='point'
LEFT JOIN public.planet_osm_line_aerospace_scored    l ON k.osm_id = l.osm_id AND k.source_table='line'
LEFT JOIN public.planet_osm_polygon_aerospace_scored g ON k.osm_id = g.osm_id AND k.source_table='polygon'
WHERE k.aerospace_score >= 10
ORDER BY k.aerospace_score DESC
LIMIT 5000;

-- STEP 5: Analysis queries
SELECT 'Total candidates' AS metric, COUNT(*) AS value FROM public.aerospace_supplier_candidates;
SELECT 'With contact info', COUNT(*) FROM public.aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL;
SELECT 'High confidence', COUNT(*) FROM public.aerospace_supplier_candidates WHERE confidence_level = 'high';

-- Classification breakdown
SELECT tier_classification, COUNT(*) AS count, AVG(aerospace_score) AS avg_score FROM public.aerospace_supplier_candidates GROUP BY tier_classification ORDER BY avg_score DESC;

-- Top candidates
SELECT name, tier_classification, aerospace_score, postcode FROM public.aerospace_supplier_candidates WHERE tier_classification IN ('tier1_candidate','tier2_candidate') ORDER BY aerospace_score DESC LIMIT 20;