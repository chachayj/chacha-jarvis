-- "OSMB"."OSMB-incheon-gus" definition

-- Drop table

-- DROP TABLE "OSMB"."OSMB-incheon-gus";

CREATE TABLE "OSMB"."OSMB-incheon-gus" (
	id serial4 NOT NULL,
	geom public.geometry(multipolygon, 4326) NULL,
	osm_id int4 NULL,
	"name" varchar NULL,
	name_en varchar NULL,
	boundary varchar NULL,
	admin_level int4 NULL,
	admin_centre_node_id int4 NULL,
	admin_centre_node_lat float8 NULL,
	admin_centre_node_lng float8 NULL,
	label_node_id int8 NULL,
	label_node_lat float8 NULL,
	label_node_lng float8 NULL,
	CONSTRAINT "OSMB-incheon-gus_pkey" PRIMARY KEY (id)
);