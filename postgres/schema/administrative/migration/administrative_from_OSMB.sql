  
  -- 인천 구(區) OSM → administrative_districts 마이그레이션
-- district_code = 'KR-INCHEON-' || UPPER( 영문/한글명에서 영숫자만 남긴 값 )
INSERT INTO administrative.administrative_districts
( province_code, province_name, country_code, district_code,
  geom, osm_id, name, name_en, boundary, admin_level,
  admin_centre_node_id, admin_centre_node_lat, admin_centre_node_lng,
  label_node_id, label_node_lat, label_node_lng )
SELECT
  'KR-INCHEON'::text AS province_code,
  '인천광역시'::text AS province_name,
  'KR'::char(2)      AS country_code,
  'KR-INCHEON-' ||
  UPPER(
    REGEXP_REPLACE(
      COALESCE(g.name_en, g."name"),
      '[^A-Za-z0-9]+',  -- 영숫자만 남기고 제거
      '',
      'g'
    )
  )                   AS district_code,

  ST_Multi(ST_MakeValid(
    CASE
      WHEN ST_SRID(g.geom) = 4326 THEN g.geom
      WHEN ST_SRID(g.geom) = 0    THEN ST_SetSRID(g.geom, 4326)
      ELSE ST_Transform(g.geom, 4326)
    END
  ))                                           AS geom,
  NULLIF(g.osm_id::text,'')::bigint            AS osm_id,
  g."name"::text                               AS name,
  g.name_en::text                              AS name_en,
  g.boundary::text                             AS boundary,
  NULLIF(g.admin_level::text,'')::int          AS admin_level,
  NULLIF(g.admin_centre_node_id::text,'')::bigint            AS admin_centre_node_id,
  NULLIF(g.admin_centre_node_lat::text,'')::double precision AS admin_centre_node_lat,
  NULLIF(g.admin_centre_node_lng::text,'')::double precision AS admin_centre_node_lng,
  NULLIF(g.label_node_id::text,'')::bigint                 AS label_node_id,
  NULLIF(g.label_node_lat::text,'')::double precision      AS label_node_lat,
  NULLIF(g.label_node_lng::text,'')::double precision      AS label_node_lng
FROM administrative."OSMB-incheon-gus" AS g
WHERE g.geom IS NOT NULL
  AND NULLIF(BTRIM(COALESCE(g.name_en, g."name")::text), '') IS NOT NULL
ON CONFLICT (province_code, district_code) DO UPDATE
SET province_name           = EXCLUDED.province_name,
    country_code            = EXCLUDED.country_code,
    geom                    = EXCLUDED.geom,
    osm_id                  = EXCLUDED.osm_id,
    name                    = EXCLUDED.name,
    name_en                 = EXCLUDED.name_en,
    boundary                = EXCLUDED.boundary,
    admin_level             = EXCLUDED.admin_level,
    admin_centre_node_id    = EXCLUDED.admin_centre_node_id,
    admin_centre_node_lat   = EXCLUDED.admin_centre_node_lat,
    admin_centre_node_lng   = EXCLUDED.admin_centre_node_lng,
    label_node_id           = EXCLUDED.label_node_id,
    label_node_lat          = EXCLUDED.label_node_lat,
    label_node_lng          = EXCLUDED.label_node_lng;
  
  
  
  
  
  
  
  
  
  
  
  
  -- OSM 서울 구 → administrative.administrative_districts 마이그레이션
-- district_code = 'KR-SEOUL-' || UPPER( 영문/한글명에서 영숫자만 남긴 값 )
INSERT INTO administrative.administrative_districts
( province_code, province_name, country_code, district_code,
  geom, osm_id, name, name_en, boundary, admin_level,
  admin_centre_node_id, admin_centre_node_lat, admin_centre_node_lng,
  label_node_id, label_node_lat, label_node_lng )
SELECT
  'KR-SEOUL'::text AS province_code,
  '서울특별시'::text AS province_name,
  'KR'::char(2)     AS country_code,
  'KR-SEOUL-' ||
  UPPER(
    REGEXP_REPLACE(
      COALESCE(g.name_en, g."name"),
      '[^A-Za-z0-9]+',  -- 영숫자만 남김
      '',
      'g'
    )
  ) AS district_code,

  ST_Multi(ST_MakeValid(
    CASE
      WHEN ST_SRID(g.geom) = 4326 THEN g.geom
      WHEN ST_SRID(g.geom) = 0    THEN ST_SetSRID(g.geom, 4326)
      ELSE ST_Transform(g.geom, 4326)
    END
  ))                                            AS geom,
  NULLIF(g.osm_id::text,'')::bigint             AS osm_id,
  g."name"::text                                AS name,
  g.name_en::text                               AS name_en,
  g.boundary::text                              AS boundary,
  NULLIF(g.admin_level::text,'')::int           AS admin_level,
  NULLIF(g.admin_centre_node_id::text,'')::bigint            AS admin_centre_node_id,
  NULLIF(g.admin_centre_node_lat::text,'')::double precision AS admin_centre_node_lat,
  NULLIF(g.admin_centre_node_lng::text,'')::double precision AS admin_centre_node_lng,
  NULLIF(g.label_node_id::text,'')::bigint                  AS label_node_id,
  NULLIF(g.label_node_lat::text,'')::double precision       AS label_node_lat,
  NULLIF(g.label_node_lng::text,'')::double precision       AS label_node_lng
FROM administrative."OSMB-seoul-gus" AS g
WHERE g.geom IS NOT NULL
  AND NULLIF(BTRIM(COALESCE(g.name_en, g."name")::text), '') IS NOT NULL
ON CONFLICT (province_code, district_code) DO UPDATE
SET province_name           = EXCLUDED.province_name,
    country_code            = EXCLUDED.country_code,
    geom                    = EXCLUDED.geom,
    osm_id                  = EXCLUDED.osm_id,
    name                    = EXCLUDED.name,
    name_en                 = EXCLUDED.name_en,
    boundary                = EXCLUDED.boundary,
    admin_level             = EXCLUDED.admin_level,
    admin_centre_node_id    = EXCLUDED.admin_centre_node_id,
    admin_centre_node_lat   = EXCLUDED.admin_centre_node_lat,
    admin_centre_node_lng   = EXCLUDED.admin_centre_node_lng,
    label_node_id           = EXCLUDED.label_node_id,
    label_node_lat          = EXCLUDED.label_node_lat,
    label_node_lng          = EXCLUDED.label_node_lng;






  -- OSM 수원 구 → administrative.administrative_districts 마이그레이션 (영문명 직접 매핑)
INSERT INTO administrative.administrative_districts
( province_code, province_name, country_code, district_code,
  geom, osm_id, name, name_en, boundary, admin_level,
  admin_centre_node_id, admin_centre_node_lat, admin_centre_node_lng,
  label_node_id, label_node_lat, label_node_lng )
SELECT
  'KR-SUWON'::text AS province_code,
  '수원시'::text   AS province_name,
  'KR'::char(2)    AS country_code,
  'KR-SUWON-' ||
  UPPER(
    REGEXP_REPLACE(
      CASE g."name"
        WHEN '팔달구' THEN 'Paldal-gu'
        WHEN '권선구' THEN 'Gwonseon-gu'
        WHEN '영통구' THEN 'Yeongtong-gu'
        WHEN '장안구' THEN 'Jangan-gu'
        ELSE g."name"
      END,
      '[^A-Za-z0-9]+',  -- 영숫자만 남김
      '',
      'g'
    )
  ) AS district_code,

  ST_Multi(ST_MakeValid(
    CASE
      WHEN ST_SRID(g.geom) = 4326 THEN g.geom
      WHEN ST_SRID(g.geom) = 0    THEN ST_SetSRID(g.geom, 4326)
      ELSE ST_Transform(g.geom, 4326)
    END
  ))                                            AS geom,
  NULLIF(g.osm_id::text,'')::bigint             AS osm_id,
  g."name"::text                                AS name,
  CASE g."name"
    WHEN '팔달구' THEN 'Paldal-gu'
    WHEN '권선구' THEN 'Gwonseon-gu'
    WHEN '영통구' THEN 'Yeongtong-gu'
    WHEN '장안구' THEN 'Jangan-gu'
    ELSE NULL
  END                                           AS name_en,
  g.boundary::text                              AS boundary,
  NULLIF(g.admin_level::text,'')::int           AS admin_level,
  NULLIF(g.admin_centre_node_id::text,'')::bigint            AS admin_centre_node_id,
  NULLIF(g.admin_centre_node_lat::text,'')::double precision AS admin_centre_node_lat,
  NULLIF(g.admin_centre_node_lng::text,'')::double precision AS admin_centre_node_lng,
  NULLIF(g.label_node_id::text,'')::bigint                  AS label_node_id,
  NULLIF(g.label_node_lat::text,'')::double precision       AS label_node_lat,
  NULLIF(g.label_node_lng::text,'')::double precision       AS label_node_lng
FROM "OSMB"."OSMB-suwon-gus" AS g
WHERE g.geom IS NOT NULL
  AND NULLIF(BTRIM(g."name"::text), '') IS NOT NULL
ON CONFLICT (province_code, district_code) DO UPDATE
SET province_name           = EXCLUDED.province_name,
    country_code            = EXCLUDED.country_code,
    geom                    = EXCLUDED.geom,
    osm_id                  = EXCLUDED.osm_id,
    name                    = EXCLUDED.name,
    name_en                 = EXCLUDED.name_en,
    boundary                = EXCLUDED.boundary,
    admin_level             = EXCLUDED.admin_level,
    admin_centre_node_id    = EXCLUDED.admin_centre_node_id,
    admin_centre_node_lat   = EXCLUDED.admin_centre_node_lat,
    admin_centre_node_lng   = EXCLUDED.admin_centre_node_lng,
    label_node_id           = EXCLUDED.label_node_id,
    label_node_lat          = EXCLUDED.label_node_lat,
    label_node_lng          = EXCLUDED.label_node_lng;

