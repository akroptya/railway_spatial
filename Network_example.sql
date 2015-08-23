-- Nodes table 
CREATE TABLE us_intersections (
node_id NUMBER,
location SDO_GEOMETRY,
CONSTRAINT us_intersections_pk PRIMARY KEY (node_id)
);

drop table ND_stations;
create table ND_stations (node_id primary key, GEOM, NODE_NAME) as
select 
to_number(K_ESR) node_id, -- Unique identification for that node in the network. 
GEOM, -- A point geometry object that contains the coordinates of the node
NU_STAN NODE_NAME        
from gps_station;

drop table ND_station_links;
create table ND_station_links (LINK_ID primary key, START_NODE_ID, END_NODE_ID, geom, link_length) as
select 
rownum LINK_ID, -- Unique identification for that link in the network.
to_number(K_ESR1) START_NODE_ID, -- Unique identifier of the node from which the link originates.
to_number(K_ESR2) END_NODE_ID, -- Unique identifier of the node at which the link terminates.
geom,
SDO_GEOM.SDO_LENGTH(geom, 0.5, 'unit=KM') link_length
from test2
where K_ESR1 != K_ESR2;

CREATE TABLE ND_paths (
path_id NUMBER PRIMARY KEY,
start_node_id NUMBER NOT NULL,
end_node_id NUMBER NOT NULL,
cost NUMBER,
simple VARCHAR2(1),
path_geom SDO_GEOMETRY);

CREATE TABLE ND_path_links (
path_id number,
link_id number,
seq_no number,
PRIMARY KEY (path_id, link_id)
);

INSERT INTO USER_SDO_NETWORK_METADATA (
NETWORK,
NETWORK_CATEGORY,
GEOMETRY_TYPE,
NO_OF_HIERARCHY_LEVELS,
NO_OF_PARTITIONS,
LINK_DIRECTION,
NODE_TABLE_NAME,
NODE_GEOM_COLUMN,
NODE_COST_COLUMN,
LINK_TABLE_NAME,
LINK_GEOM_COLUMN,
LINK_COST_COLUMN,
PATH_TABLE_NAME,
PATH_GEOM_COLUMN,
PATH_LINK_TABLE_NAME
)
VALUES (
'STATIONS_ROADS',     -- network (primary key)
'SPATIAL',      -- network_category
'SDO_GEOMETRY', -- geometry_type
1, -- no_of_hierarchy_levels
1, -- no_of_partitions
'UNDIRECTED', -- link_direction
'ND_STATIONS', -- node_table_name
'GEOM', -- node_geom_column
NULL, -- node_cost_column (no cost at node level)
'ND_STATION_LINKS', -- link_table_name
'GEOM', -- link_geom_column
'LINK_LENGTH', -- link_cost_column
'ND_PATHS', -- path_table_name
'PATH_GEOM', -- path_geom_column
'ND_PATH_LINKS' -- path_link_table_name
);
COMMIT;


INSERT INTO USER_SDO_GEOM_METADATA VALUES
(
'ND_PATHS',  'PATH_GEOM', SDO_DIM_ARRAY
(
SDO_DIM_ELEMENT
(
'LONGITUDE',    -180,           180,            0.5             
),
SDO_DIM_ELEMENT
(
'LATITUDE', -90,        90,         0.5         
)
),
8307 -- SRID value for specifying a geodetic coordinate system
);
commit;


select sdo_net.validate_network('STATIONS_ROADS') from dual;

-- кол-во узлов в сети
select SDO_NET.GET_NO_OF_NODES('STATIONS_ROADS') from dual;

-- кол-во рЄбер в сети
select SDO_NET.GET_NO_OF_LINKS('STATIONS_ROADS') from dual;

-- узлы к которым нет рЄбер
select SDO_NET.GET_ISOLATED_NODES('STATIONS_ROADS') from dual;
-- 458217, 473306 

-- рЄбра концов которых нет в списке узлов
select SDO_NET.GET_INVALID_LINKS('STATIONS_ROADS') from dual;

-- количество рЄбер 
select SDO_NET.GET_NODE_DEGREE('STATIONS_ROADS',a.k_Esr), a.*
from gps_station a
order by 1 desc;

-- вход€шие и исход€щие рЄбра
select  SDO_NET.GET_IN_LINKS('STATIONS_ROADS',a.k_Esr),
        SDO_NET.GET_OUT_LINKS('STATIONS_ROADS',a.k_Esr)
from gps_station a
where K_ESR = '413305';


select *
from gps_station a;

-- length (value) fro shortest path between Kyiv and Ternopil
-- 482,622381002628 km
declare
PATH NUMBER;
link_array SDO_NUMBER_ARRAY;
node_array SDO_NUMBER_ARRAY;
begin
--SDO_NET_MEM.NETWORK_MANAGER.READ_NETWORK('STATIONS_ROADS','FALSE');
PATH := SDO_NET_MEM.NETWORK_MANAGER.SHORTEST_PATH('STATIONS_ROADS', 320308, 360004);

-- Ensure that we have connection between stations
IF path IS NULL THEN
    DBMS_OUTPUT.PUT_LINE('No paths exists');
    RETURN;
END IF;
DBMS_OUTPUT.PUT_LINE('Length (value): '||SDO_NET_MEM.PATH.GET_COST('STATIONS_ROADS', path));
DBMS_OUTPUT.PUT_LINE('Number of spans:' ||SDO_NET_MEM.PATH.GET_NO_OF_LINKS('STATIONS_ROADS', path));

-- spans of shortest path
DBMS_OUTPUT.PUT_LINE('Spans:');
link_array := SDO_NET_MEM.PATH.GET_LINK_IDS('STATIONS_ROADS', path);
FOR i IN link_array.first..link_array.last LOOP
    DBMS_OUTPUT.PUT_LINE('от ' || 
    SDO_NET_MEM.LINK.GET_START_NODE_ID('STATIONS_ROADS', link_array(i)) || ' до ' ||
    SDO_NET_MEM.LINK.GET_END_NODE_ID('STATIONS_ROADS', link_array(i)) || ' ' ||
    SDO_NET_MEM.LINK.GET_COST('STATIONS_ROADS', link_array(i))
);
END LOOP;

end;

/*
Visualization and editing

set ORACLE_HOME=D:\oracle\product\11.2.0\dbhome_1
set JAR_LIBS=%ORACLE_HOME%\md\jlib\sdondme.jar;%ORACLE_HOME%\md\jlib\xmlparserv2.jar;%ORACLE_HOME%\md\jlib\classes12.jar;%ORACLE_HOME%\md\jlib\sdonm.jar;%ORACLE_HOME%\md\jlib\sdoapi.jar;%ORACLE_HOME%\md\jlib\sdoutl.jar
java -Xms512M -Xmx512M -cp %JAR_LIBS% oracle.spatial.network.editor.NetworkEditor

*/
