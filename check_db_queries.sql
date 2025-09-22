-- Basic database checks
-- Count nodes, ways, polygons, roads
SELECT COUNT(*) AS nodes_count FROM planet_osm_nodes;
SELECT COUNT(*) AS ways_count FROM planet_osm_ways;
SELECT COUNT(*) AS polygons_count FROM planet_osm_polygon;
SELECT COUNT(*) AS roads_count FROM planet_osm_roads;
-- Check table sizes
SELECT relname AS table_name, pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
-- Top 10 populated tags in planet_osm_point
SELECT (tags::hstore)->'amenity' AS amenity, COUNT(*) AS count
FROM planet_osm_point
WHERE tags ? 'amenity'
GROUP BY (tags::hstore)->'amenity'
ORDER BY count DESC
LIMIT 10;
-- Top 10 populated highway types in roads
SELECT (tags::hstore)->'highway' AS highway_type, COUNT(*) AS count
FROM planet_osm_roads
WHERE tags ? 'highway'
GROUP BY (tags::hstore)->'highway'
ORDER BY count DESC
LIMIT 10;
