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
