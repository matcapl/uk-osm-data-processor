-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM
-- Generated on: 2025-10-02 11:36:55
-- Schema: public

-- STEP 1: Exclusions
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


-- STEP 2: Scoring (scored-view creation)
-- Aerospace Supplier Scoring SQL
-- Generated: 2025-10-02T10:36:55.871337
-- Schema: public

-- Scored view for planet_osm_point
DROP VIEW IF EXISTS public.planet_osm_point_aerospace_scored CASCADE;
CREATE VIEW public.planet_osm_point_aerospace_scored AS
SELECT
  src.*,
  (
    CASE
    WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%bae%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%safran%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%')) OR src."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(src."name") LIKE LOWER('%defense%') OR LOWER(src."name") LIKE LOWER('%defence%') OR LOWER(src."name") LIKE LOWER('%military%') OR LOWER(src."name") LIKE LOWER('%radar%') OR LOWER(src."name") LIKE LOWER('%missile%') OR LOWER(src."name") LIKE LOWER('%weapons%')) OR src."military" IS NOT NULL OR src."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(src."name") LIKE LOWER('%engineering%') OR LOWER(src."name") LIKE LOWER('%technology%') OR LOWER(src."name") LIKE LOWER('%systems%') OR LOWER(src."name") LIKE LOWER('%electronics%') OR LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%advanced%')) OR src."man_made" IN ('works','factory') OR src."office" IN ('engineering','research','technology')) THEN 70
    WHEN (src."landuse" IN ('industrial')) THEN 50
    WHEN ((LOWER(src."name") LIKE LOWER('%research%') OR LOWER(src."name") LIKE LOWER('%development%') OR LOWER(src."name") LIKE LOWER('%laboratory%') OR LOWER(src."name") LIKE LOWER('%institute%') OR LOWER(src."name") LIKE LOWER('%university%')) OR src."office" IN ('research','engineering') OR src."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%bae systems%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%') OR LOWER(src."name") LIKE LOWER('%safran%')) OR (LOWER(src."operator") LIKE LOWER('%boeing%') OR LOWER(src."operator") LIKE LOWER('%airbus%') OR LOWER(src."operator") LIKE LOWER('%rolls royce%') OR LOWER(src."operator") LIKE LOWER('%bae systems%') OR LOWER(src."operator") LIKE LOWER('%leonardo%') OR LOWER(src."operator") LIKE LOWER('%thales%') OR LOWER(src."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%avionics%') OR LOWER(src."name") LIKE LOWER('%turbine%') OR LOWER(src."name") LIKE LOWER('%engine%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%') OR LOWER(src."operator") LIKE LOWER('%avionics%') OR LOWER(src."operator") LIKE LOWER('%turbine%') OR LOWER(src."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%machining%') OR LOWER(src."name") LIKE LOWER('%casting%') OR LOWER(src."name") LIKE LOWER('%forging%') OR LOWER(src."name") LIKE LOWER('%composite%') OR LOWER(src."name") LIKE LOWER('%materials%')) OR (LOWER(src."operator") LIKE LOWER('%precision%') OR LOWER(src."operator") LIKE LOWER('%machining%') OR LOWER(src."operator") LIKE LOWER('%casting%') OR LOWER(src."operator") LIKE LOWER('%forging%') OR LOWER(src."operator") LIKE LOWER('%composite%') OR LOWER(src."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (src."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR src."shop" IS NOT NULL OR src."tourism" IS NOT NULL OR src."leisure" IS NOT NULL) THEN -50 ELSE 0 END +
    CASE WHEN (src."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (src."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR src."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) AS aerospace_score,
  ARRAY[]::text[] AS matched_keywords,
  'planet_osm_point'              AS source_table
FROM public.planet_osm_point_aerospace_filtered flt
JOIN public.planet_osm_point src ON flt.osm_id = src.osm_id
WHERE
  (
    CASE
    WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%bae%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%safran%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%')) OR src."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(src."name") LIKE LOWER('%defense%') OR LOWER(src."name") LIKE LOWER('%defence%') OR LOWER(src."name") LIKE LOWER('%military%') OR LOWER(src."name") LIKE LOWER('%radar%') OR LOWER(src."name") LIKE LOWER('%missile%') OR LOWER(src."name") LIKE LOWER('%weapons%')) OR src."military" IS NOT NULL OR src."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(src."name") LIKE LOWER('%engineering%') OR LOWER(src."name") LIKE LOWER('%technology%') OR LOWER(src."name") LIKE LOWER('%systems%') OR LOWER(src."name") LIKE LOWER('%electronics%') OR LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%advanced%')) OR src."man_made" IN ('works','factory') OR src."office" IN ('engineering','research','technology')) THEN 70
    WHEN (src."landuse" IN ('industrial')) THEN 50
    WHEN ((LOWER(src."name") LIKE LOWER('%research%') OR LOWER(src."name") LIKE LOWER('%development%') OR LOWER(src."name") LIKE LOWER('%laboratory%') OR LOWER(src."name") LIKE LOWER('%institute%') OR LOWER(src."name") LIKE LOWER('%university%')) OR src."office" IN ('research','engineering') OR src."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%bae systems%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%') OR LOWER(src."name") LIKE LOWER('%safran%')) OR (LOWER(src."operator") LIKE LOWER('%boeing%') OR LOWER(src."operator") LIKE LOWER('%airbus%') OR LOWER(src."operator") LIKE LOWER('%rolls royce%') OR LOWER(src."operator") LIKE LOWER('%bae systems%') OR LOWER(src."operator") LIKE LOWER('%leonardo%') OR LOWER(src."operator") LIKE LOWER('%thales%') OR LOWER(src."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%avionics%') OR LOWER(src."name") LIKE LOWER('%turbine%') OR LOWER(src."name") LIKE LOWER('%engine%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%') OR LOWER(src."operator") LIKE LOWER('%avionics%') OR LOWER(src."operator") LIKE LOWER('%turbine%') OR LOWER(src."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%machining%') OR LOWER(src."name") LIKE LOWER('%casting%') OR LOWER(src."name") LIKE LOWER('%forging%') OR LOWER(src."name") LIKE LOWER('%composite%') OR LOWER(src."name") LIKE LOWER('%materials%')) OR (LOWER(src."operator") LIKE LOWER('%precision%') OR LOWER(src."operator") LIKE LOWER('%machining%') OR LOWER(src."operator") LIKE LOWER('%casting%') OR LOWER(src."operator") LIKE LOWER('%forging%') OR LOWER(src."operator") LIKE LOWER('%composite%') OR LOWER(src."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (src."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR src."shop" IS NOT NULL OR src."tourism" IS NOT NULL OR src."leisure" IS NOT NULL) THEN -50 ELSE 0 END +
    CASE WHEN (src."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (src."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR src."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) > 0;

-- Scored view for planet_osm_line
DROP VIEW IF EXISTS public.planet_osm_line_aerospace_scored CASCADE;
CREATE VIEW public.planet_osm_line_aerospace_scored AS
SELECT
  src.*,
  (
    CASE
    WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%bae%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%safran%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%')) OR src."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(src."name") LIKE LOWER('%defense%') OR LOWER(src."name") LIKE LOWER('%defence%') OR LOWER(src."name") LIKE LOWER('%military%') OR LOWER(src."name") LIKE LOWER('%radar%') OR LOWER(src."name") LIKE LOWER('%missile%') OR LOWER(src."name") LIKE LOWER('%weapons%')) OR src."military" IS NOT NULL OR src."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(src."name") LIKE LOWER('%engineering%') OR LOWER(src."name") LIKE LOWER('%technology%') OR LOWER(src."name") LIKE LOWER('%systems%') OR LOWER(src."name") LIKE LOWER('%electronics%') OR LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%advanced%')) OR src."industrial" IN ('engineering','electronics','precision','high_tech') OR src."man_made" IN ('works','factory') OR src."office" IN ('engineering','research','technology') OR src."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (src."landuse" IN ('industrial') OR src."building" IN ('industrial','warehouse','manufacture') OR src."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(src."name") LIKE LOWER('%research%') OR LOWER(src."name") LIKE LOWER('%development%') OR LOWER(src."name") LIKE LOWER('%laboratory%') OR LOWER(src."name") LIKE LOWER('%institute%') OR LOWER(src."name") LIKE LOWER('%university%')) OR src."office" IN ('research','engineering') OR src."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%bae systems%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%') OR LOWER(src."name") LIKE LOWER('%safran%')) OR (LOWER(src."operator") LIKE LOWER('%boeing%') OR LOWER(src."operator") LIKE LOWER('%airbus%') OR LOWER(src."operator") LIKE LOWER('%rolls royce%') OR LOWER(src."operator") LIKE LOWER('%bae systems%') OR LOWER(src."operator") LIKE LOWER('%leonardo%') OR LOWER(src."operator") LIKE LOWER('%thales%') OR LOWER(src."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%avionics%') OR LOWER(src."name") LIKE LOWER('%turbine%') OR LOWER(src."name") LIKE LOWER('%engine%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%') OR LOWER(src."operator") LIKE LOWER('%avionics%') OR LOWER(src."operator") LIKE LOWER('%turbine%') OR LOWER(src."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%machining%') OR LOWER(src."name") LIKE LOWER('%casting%') OR LOWER(src."name") LIKE LOWER('%forging%') OR LOWER(src."name") LIKE LOWER('%composite%') OR LOWER(src."name") LIKE LOWER('%materials%')) OR (LOWER(src."operator") LIKE LOWER('%precision%') OR LOWER(src."operator") LIKE LOWER('%machining%') OR LOWER(src."operator") LIKE LOWER('%casting%') OR LOWER(src."operator") LIKE LOWER('%forging%') OR LOWER(src."operator") LIKE LOWER('%composite%') OR LOWER(src."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (src."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR src."shop" IS NOT NULL OR src."tourism" IS NOT NULL OR src."leisure" IS NOT NULL OR src."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (src."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (src."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR src."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) AS aerospace_score,
  ARRAY[]::text[] AS matched_keywords,
  'planet_osm_line'              AS source_table
FROM public.planet_osm_line_aerospace_filtered flt
JOIN public.planet_osm_line src ON flt.osm_id = src.osm_id
WHERE
  (
    CASE
    WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%bae%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%safran%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%')) OR src."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(src."name") LIKE LOWER('%defense%') OR LOWER(src."name") LIKE LOWER('%defence%') OR LOWER(src."name") LIKE LOWER('%military%') OR LOWER(src."name") LIKE LOWER('%radar%') OR LOWER(src."name") LIKE LOWER('%missile%') OR LOWER(src."name") LIKE LOWER('%weapons%')) OR src."military" IS NOT NULL OR src."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(src."name") LIKE LOWER('%engineering%') OR LOWER(src."name") LIKE LOWER('%technology%') OR LOWER(src."name") LIKE LOWER('%systems%') OR LOWER(src."name") LIKE LOWER('%electronics%') OR LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%advanced%')) OR src."industrial" IN ('engineering','electronics','precision','high_tech') OR src."man_made" IN ('works','factory') OR src."office" IN ('engineering','research','technology') OR src."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (src."landuse" IN ('industrial') OR src."building" IN ('industrial','warehouse','manufacture') OR src."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(src."name") LIKE LOWER('%research%') OR LOWER(src."name") LIKE LOWER('%development%') OR LOWER(src."name") LIKE LOWER('%laboratory%') OR LOWER(src."name") LIKE LOWER('%institute%') OR LOWER(src."name") LIKE LOWER('%university%')) OR src."office" IN ('research','engineering') OR src."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%bae systems%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%') OR LOWER(src."name") LIKE LOWER('%safran%')) OR (LOWER(src."operator") LIKE LOWER('%boeing%') OR LOWER(src."operator") LIKE LOWER('%airbus%') OR LOWER(src."operator") LIKE LOWER('%rolls royce%') OR LOWER(src."operator") LIKE LOWER('%bae systems%') OR LOWER(src."operator") LIKE LOWER('%leonardo%') OR LOWER(src."operator") LIKE LOWER('%thales%') OR LOWER(src."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%avionics%') OR LOWER(src."name") LIKE LOWER('%turbine%') OR LOWER(src."name") LIKE LOWER('%engine%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%') OR LOWER(src."operator") LIKE LOWER('%avionics%') OR LOWER(src."operator") LIKE LOWER('%turbine%') OR LOWER(src."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%machining%') OR LOWER(src."name") LIKE LOWER('%casting%') OR LOWER(src."name") LIKE LOWER('%forging%') OR LOWER(src."name") LIKE LOWER('%composite%') OR LOWER(src."name") LIKE LOWER('%materials%')) OR (LOWER(src."operator") LIKE LOWER('%precision%') OR LOWER(src."operator") LIKE LOWER('%machining%') OR LOWER(src."operator") LIKE LOWER('%casting%') OR LOWER(src."operator") LIKE LOWER('%forging%') OR LOWER(src."operator") LIKE LOWER('%composite%') OR LOWER(src."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (src."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR src."shop" IS NOT NULL OR src."tourism" IS NOT NULL OR src."leisure" IS NOT NULL OR src."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (src."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (src."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR src."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) > 0;

-- Scored view for planet_osm_polygon
DROP VIEW IF EXISTS public.planet_osm_polygon_aerospace_scored CASCADE;
CREATE VIEW public.planet_osm_polygon_aerospace_scored AS
SELECT
  src.*,
  (
    CASE
    WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%bae%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%safran%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%')) OR src."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(src."name") LIKE LOWER('%defense%') OR LOWER(src."name") LIKE LOWER('%defence%') OR LOWER(src."name") LIKE LOWER('%military%') OR LOWER(src."name") LIKE LOWER('%radar%') OR LOWER(src."name") LIKE LOWER('%missile%') OR LOWER(src."name") LIKE LOWER('%weapons%')) OR src."military" IS NOT NULL OR src."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(src."name") LIKE LOWER('%engineering%') OR LOWER(src."name") LIKE LOWER('%technology%') OR LOWER(src."name") LIKE LOWER('%systems%') OR LOWER(src."name") LIKE LOWER('%electronics%') OR LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%advanced%')) OR src."industrial" IN ('engineering','electronics','precision','high_tech') OR src."man_made" IN ('works','factory') OR src."office" IN ('engineering','research','technology') OR src."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (src."landuse" IN ('industrial') OR src."building" IN ('industrial','warehouse','manufacture') OR src."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(src."name") LIKE LOWER('%research%') OR LOWER(src."name") LIKE LOWER('%development%') OR LOWER(src."name") LIKE LOWER('%laboratory%') OR LOWER(src."name") LIKE LOWER('%institute%') OR LOWER(src."name") LIKE LOWER('%university%')) OR src."office" IN ('research','engineering') OR src."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%bae systems%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%') OR LOWER(src."name") LIKE LOWER('%safran%')) OR (LOWER(src."operator") LIKE LOWER('%boeing%') OR LOWER(src."operator") LIKE LOWER('%airbus%') OR LOWER(src."operator") LIKE LOWER('%rolls royce%') OR LOWER(src."operator") LIKE LOWER('%bae systems%') OR LOWER(src."operator") LIKE LOWER('%leonardo%') OR LOWER(src."operator") LIKE LOWER('%thales%') OR LOWER(src."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%avionics%') OR LOWER(src."name") LIKE LOWER('%turbine%') OR LOWER(src."name") LIKE LOWER('%engine%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%') OR LOWER(src."operator") LIKE LOWER('%avionics%') OR LOWER(src."operator") LIKE LOWER('%turbine%') OR LOWER(src."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%machining%') OR LOWER(src."name") LIKE LOWER('%casting%') OR LOWER(src."name") LIKE LOWER('%forging%') OR LOWER(src."name") LIKE LOWER('%composite%') OR LOWER(src."name") LIKE LOWER('%materials%')) OR (LOWER(src."operator") LIKE LOWER('%precision%') OR LOWER(src."operator") LIKE LOWER('%machining%') OR LOWER(src."operator") LIKE LOWER('%casting%') OR LOWER(src."operator") LIKE LOWER('%forging%') OR LOWER(src."operator") LIKE LOWER('%composite%') OR LOWER(src."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (src."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR src."shop" IS NOT NULL OR src."tourism" IS NOT NULL OR src."leisure" IS NOT NULL OR src."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (src."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (src."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR src."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) AS aerospace_score,
  ARRAY[]::text[] AS matched_keywords,
  'planet_osm_polygon'              AS source_table
FROM public.planet_osm_polygon_aerospace_filtered flt
JOIN public.planet_osm_polygon src ON flt.osm_id = src.osm_id
WHERE
  (
    CASE
    WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%bae%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%safran%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%')) OR src."office" IN ('aerospace','aviation')) THEN 100
    WHEN ((LOWER(src."name") LIKE LOWER('%defense%') OR LOWER(src."name") LIKE LOWER('%defence%') OR LOWER(src."name") LIKE LOWER('%military%') OR LOWER(src."name") LIKE LOWER('%radar%') OR LOWER(src."name") LIKE LOWER('%missile%') OR LOWER(src."name") LIKE LOWER('%weapons%')) OR src."military" IS NOT NULL OR src."landuse" IN ('military')) THEN 80
    WHEN ((LOWER(src."name") LIKE LOWER('%engineering%') OR LOWER(src."name") LIKE LOWER('%technology%') OR LOWER(src."name") LIKE LOWER('%systems%') OR LOWER(src."name") LIKE LOWER('%electronics%') OR LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%advanced%')) OR src."industrial" IN ('engineering','electronics','precision','high_tech') OR src."man_made" IN ('works','factory') OR src."office" IN ('engineering','research','technology') OR src."building" IN ('industrial','factory','warehouse')) THEN 70
    WHEN (src."landuse" IN ('industrial') OR src."building" IN ('industrial','warehouse','manufacture') OR src."industrial" IS NOT NULL) THEN 50
    WHEN ((LOWER(src."name") LIKE LOWER('%research%') OR LOWER(src."name") LIKE LOWER('%development%') OR LOWER(src."name") LIKE LOWER('%laboratory%') OR LOWER(src."name") LIKE LOWER('%institute%') OR LOWER(src."name") LIKE LOWER('%university%')) OR src."office" IN ('research','engineering') OR src."amenity" IN ('research_institute','university')) THEN 60
    ELSE 0
END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%boeing%') OR LOWER(src."name") LIKE LOWER('%airbus%') OR LOWER(src."name") LIKE LOWER('%rolls royce%') OR LOWER(src."name") LIKE LOWER('%bae systems%') OR LOWER(src."name") LIKE LOWER('%leonardo%') OR LOWER(src."name") LIKE LOWER('%thales%') OR LOWER(src."name") LIKE LOWER('%safran%')) OR (LOWER(src."operator") LIKE LOWER('%boeing%') OR LOWER(src."operator") LIKE LOWER('%airbus%') OR LOWER(src."operator") LIKE LOWER('%rolls royce%') OR LOWER(src."operator") LIKE LOWER('%bae systems%') OR LOWER(src."operator") LIKE LOWER('%leonardo%') OR LOWER(src."operator") LIKE LOWER('%thales%') OR LOWER(src."operator") LIKE LOWER('%safran%'))) THEN 50 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%aerospace%') OR LOWER(src."name") LIKE LOWER('%aviation%') OR LOWER(src."name") LIKE LOWER('%aircraft%') OR LOWER(src."name") LIKE LOWER('%avionics%') OR LOWER(src."name") LIKE LOWER('%turbine%') OR LOWER(src."name") LIKE LOWER('%engine%')) OR (LOWER(src."operator") LIKE LOWER('%aerospace%') OR LOWER(src."operator") LIKE LOWER('%aviation%') OR LOWER(src."operator") LIKE LOWER('%aircraft%') OR LOWER(src."operator") LIKE LOWER('%avionics%') OR LOWER(src."operator") LIKE LOWER('%turbine%') OR LOWER(src."operator") LIKE LOWER('%engine%'))) THEN 30 ELSE 0 END +
    CASE WHEN ((LOWER(src."name") LIKE LOWER('%precision%') OR LOWER(src."name") LIKE LOWER('%machining%') OR LOWER(src."name") LIKE LOWER('%casting%') OR LOWER(src."name") LIKE LOWER('%forging%') OR LOWER(src."name") LIKE LOWER('%composite%') OR LOWER(src."name") LIKE LOWER('%materials%')) OR (LOWER(src."operator") LIKE LOWER('%precision%') OR LOWER(src."operator") LIKE LOWER('%machining%') OR LOWER(src."operator") LIKE LOWER('%casting%') OR LOWER(src."operator") LIKE LOWER('%forging%') OR LOWER(src."operator") LIKE LOWER('%composite%') OR LOWER(src."operator") LIKE LOWER('%materials%'))) THEN 20 ELSE 0 END +
    CASE WHEN (src."amenity" IN ('restaurant','pub','cafe','bar','fast_food','fuel','hospital','school') OR src."shop" IS NOT NULL OR src."tourism" IS NOT NULL OR src."leisure" IS NOT NULL OR src."building" IN ('house','apartments','residential','hotel','retail')) THEN -50 ELSE 0 END +
    CASE WHEN (src."landuse" IN ('residential','retail','commercial','farmland')) THEN -25 ELSE 0 END +
    CASE WHEN (src."office" IN ('insurance','finance','estate_agent','lawyer','accountant') OR src."amenity" IN ('bank','post_office','library')) THEN -15 ELSE 0 END
) > 0;


-- STEP 3: Output table DDL
DROP TABLE IF EXISTS public.aerospace_supplier_candidates CASCADE;
CREATE TABLE public.aerospace_supplier_candidates (
    osm_id BIGINT,
    source_table VARCHAR(50),
    name TEXT,
    operator TEXT,
    aerospace_score INTEGER,
    tier_classification VARCHAR(50),
    confidence_level VARCHAR(50),
    phone TEXT,
    email TEXT,
    website TEXT,
    postcode VARCHAR(20),
    street_address TEXT,
    city TEXT,
    landuse_type TEXT,
    building_type TEXT,
    industrial_type TEXT,
    office_type TEXT,
    description TEXT,
    matched_keywords TEXT[],
    tags_raw HSTORE,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geometry GEOMETRY(Point,4326),
    created_at TIMESTAMP
);

-- Indexes
CREATE INDEX idx_aerospace_supplier_candidates_score    ON public.aerospace_supplier_candidates(aerospace_score);
CREATE INDEX idx_aerospace_supplier_candidates_tier     ON public.aerospace_supplier_candidates(tier_classification);
CREATE INDEX idx_aerospace_supplier_candidates_postcode ON public.aerospace_supplier_candidates(postcode);
CREATE INDEX idx_aerospace_supplier_candidates_geom     ON public.aerospace_supplier_candidates USING GIST(geometry);

-- STEP 4: Insert candidates
-- min_score = 10
INSERT INTO public.aerospace_supplier_candidates (osm_id, source_table, name, operator, aerospace_score, tier_classification, confidence_level, phone, email, website, postcode, street_address, city, landuse_type, building_type, industrial_type, office_type, description, matched_keywords, tags_raw, latitude, longitude, geometry, created_at)
SELECT osm_id, 'point' AS source_table, name, operator, aerospace_score, CASE
            WHEN aerospace_score >= 150 THEN 'tier1_candidate'
            WHEN aerospace_score >= 80  THEN 'tier2_candidate'
            WHEN aerospace_score >= 40  THEN 'potential_candidate'
            ELSE 'low_probability'
           END AS tier_classification, CASE
            WHEN aerospace_score >= 150
             AND (tags->'website' IS NOT NULL OR tags->'phone' IS NOT NULL)
            THEN 'high'
            WHEN aerospace_score >= 80  THEN 'medium'
            WHEN aerospace_score >= 40  THEN 'low'
            ELSE 'very_low'
           END AS confidence_level, tags->'phone'         AS phone, tags->'email'         AS email, tags->'website'       AS website, tags->'addr:postcode' AS postcode, tags->'addr:street'   AS street_address, tags->'addr:city'     AS city, NULL AS landuse_type, NULL AS building_type, NULL AS industrial_type, NULL AS office_type, NULL AS description, ARRAY[]::text[] AS matched_keywords, tags                 AS tags_raw, ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude, ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude, ST_Transform(ST_Centroid(way),4326) AS geometry, NOW()               AS created_at
FROM public.planet_osm_point_aerospace_scored
WHERE aerospace_score >= 10
UNION ALL
SELECT osm_id, 'line' AS source_table, name, operator, aerospace_score, CASE
            WHEN aerospace_score >= 150 THEN 'tier1_candidate'
            WHEN aerospace_score >= 80  THEN 'tier2_candidate'
            WHEN aerospace_score >= 40  THEN 'potential_candidate'
            ELSE 'low_probability'
           END AS tier_classification, CASE
            WHEN aerospace_score >= 150
             AND (tags->'website' IS NOT NULL OR tags->'phone' IS NOT NULL)
            THEN 'high'
            WHEN aerospace_score >= 80  THEN 'medium'
            WHEN aerospace_score >= 40  THEN 'low'
            ELSE 'very_low'
           END AS confidence_level, tags->'phone'         AS phone, tags->'email'         AS email, tags->'website'       AS website, tags->'addr:postcode' AS postcode, tags->'addr:street'   AS street_address, tags->'addr:city'     AS city, NULL AS landuse_type, NULL AS building_type, NULL AS industrial_type, NULL AS office_type, NULL AS description, ARRAY[]::text[] AS matched_keywords, tags                 AS tags_raw, ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude, ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude, ST_Transform(ST_Centroid(way),4326) AS geometry, NOW()               AS created_at
FROM public.planet_osm_line_aerospace_scored
WHERE aerospace_score >= 10
UNION ALL
SELECT osm_id, 'polygon' AS source_table, name, operator, aerospace_score, CASE
            WHEN aerospace_score >= 150 THEN 'tier1_candidate'
            WHEN aerospace_score >= 80  THEN 'tier2_candidate'
            WHEN aerospace_score >= 40  THEN 'potential_candidate'
            ELSE 'low_probability'
           END AS tier_classification, CASE
            WHEN aerospace_score >= 150
             AND (tags->'website' IS NOT NULL OR tags->'phone' IS NOT NULL)
            THEN 'high'
            WHEN aerospace_score >= 80  THEN 'medium'
            WHEN aerospace_score >= 40  THEN 'low'
            ELSE 'very_low'
           END AS confidence_level, tags->'phone'         AS phone, tags->'email'         AS email, tags->'website'       AS website, tags->'addr:postcode' AS postcode, tags->'addr:street'   AS street_address, tags->'addr:city'     AS city, NULL AS landuse_type, NULL AS building_type, NULL AS industrial_type, NULL AS office_type, NULL AS description, ARRAY[]::text[] AS matched_keywords, tags                 AS tags_raw, ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude, ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude, ST_Transform(ST_Centroid(way),4326) AS geometry, NOW()               AS created_at
FROM public.planet_osm_polygon_aerospace_scored
WHERE aerospace_score >= 10
ORDER BY aerospace_score DESC
LIMIT 5000;

-- STEP 5: Verification queries
SELECT 'Total candidates'    AS metric, COUNT(*)     AS value FROM public.aerospace_supplier_candidates;
SELECT 'With contact info'  AS metric, COUNT(*)     AS value FROM public.aerospace_supplier_candidates WHERE phone IS NOT NULL OR email IS NOT NULL;
SELECT 'High confidence'   AS metric, COUNT(*)     AS value FROM public.aerospace_supplier_candidates WHERE confidence_level='high';

SELECT tier_classification, COUNT(*) AS count, AVG(aerospace_score) AS avg_score
  FROM public.aerospace_supplier_candidates GROUP BY tier_classification ORDER BY avg_score DESC;

SELECT name, tier_classification, aerospace_score, postcode
  FROM public.aerospace_supplier_candidates WHERE tier_classification IN ('tier1_candidate','tier2_candidate')
  ORDER BY aerospace_score DESC LIMIT 20;