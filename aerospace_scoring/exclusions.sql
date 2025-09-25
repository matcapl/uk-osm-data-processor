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
