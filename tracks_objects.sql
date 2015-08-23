-- stations
drop table gps_station;
create table gps_station (K_ESR primary key, 
K_RP5, K_DOR,K_ADM,MNK_RP,K_OTD,N_STAN,  NU_STAN, N_STANS, NU_STANS, W_STAN,P_STAN,R_GRAN,
GEOM)
 as
select a.K_ESR, a.K_RP5, K_DOR,K_ADM,MNK_RP,K_OTD,N_STAN,  NU_STAN, N_STANS, NU_STANS, 
       W_STAN,P_STAN, R_GRAN,
       SDO_GEOMETRY(
            2001, 
            8307, 
            SDO_POINT_TYPE(
            b.LON, 
            b.LAT,
            NULL 
            ),
            NULL,
            NULL    
       )    
from PSVNSI.VS_KLASSTAN a  join gps_esr b on a.K_ESR = b.K_ESR;

-- lightins
create table gps_lightin as
SELECT  replace(replace(a.header,'#Участок движения ',''),', cветофор входной','') header, 
        a.pp, a.kod, a.height,
        a.name, a.koordinata,         
        SDO_GEOMETRY(2001, 8307,
            SDO_POINT_TYPE( floor(lon/100.0)+((lon-floor(lon/100.0)*100)/60.0), 
                            floor(lat/100.0)+((lat-floor(lat/100.0)*100)/60.0), 
                            NULL),
            NULL,NULL) geom       
  FROM raw_gps_lightin_data a;
commit;

-- tracks
create table GPS_TREK as 
select  HEADER, 
        SDO_GEOMETRY(
            2002, -- SDO_GTYPE: D00T. Set to 2002 as it is a 2-dimensional line string
            8307, -- SDO_SRID (geodetic)
            NULL, -- SDO_POINT_TYPE is null
            SDO_ELEM_INFO_ARRAY 
            (1, -- Offset is 1
            2, -- Element-type is 2 for a LINE STRING
            1 -- Interpretation is 1 if line string is connected by straight lines.
            ),
            cast(ordinates as SDO_ORDINATE_ARRAY)) geom
from
(select pp,max_pp, HEADER, 
    LineOrdinates(lon_lat(lon, lat)) over (partition by HEADER order by pp)  ordinates
from (select header, round(floor(lon/100.0)+((lon-floor(lon/100.0)*100)/60.0),6) lon, 
                     round(floor(lat/100.0)+((lat-floor(lat/100.0)*100)/60.0),6) lat,
                     pp, max(pp) over (partition by header) max_pp
from RAW_GPS_TREK_DATA
where header not in ('#Участок движения - Іллічівськ-ОдесаСорт-Чорноліс., трек',
    '#Участок движения - Чорноліс.-ОдесаСорт-Іллічівськ, трек')
order by HEADER, PP))
where pp = max_pp;


declare
    v_geom SDO_GEOMETRY;
    v_ordinates SDO_ORDINATE_ARRAY;
    v_header varchar2(1000);
begin
    v_ordinates := SDO_ORDINATE_ARRAY();
    for k in (select header, round(floor(lon/100.0)+((lon-floor(lon/100.0)*100)/60.0),6) lon, 
                     round(floor(lat/100.0)+((lat-floor(lat/100.0)*100)/60.0),6) lat
from RAW_GPS_TREK_DATA
where 
    header ='#Участок движения - Чорноліс.-ОдесаСорт-Іллічівськ, трек'
order by HEADER, PP) loop
    v_ordinates.EXTEND(2);
    v_ordinates(v_ordinates.COUNT-1) := k.lon;
    v_ordinates(v_ordinates.COUNT) := k.lat; 
    v_header := k.header;   
end loop;
    
    insert into GPS_TREK values (v_header,
        SDO_GEOMETRY
        (2002, -- SDO_GTYPE: D00T. Set to 2002 as it is a 2-dimensional line string
        8307, -- SDO_SRID (geodetic)
        NULL, -- SDO_POINT_TYPE is null
        SDO_ELEM_INFO_ARRAY 
            (1, -- Offset is 1
            2, -- Element-type is 2 for a LINE STRING
            1 -- Interpretation is 1 if line string is connected by straight lines.
            ),
        v_ordinates));            
end;    


INSERT INTO USER_SDO_GEOM_METADATA VALUES
(
'GPS_STATION',  'GEOM',         SDO_DIM_ARRAY   
(
SDO_DIM_ELEMENT
(
'LONGITUDE',    
-180,           
180,            
0.5             
),
SDO_DIM_ELEMENT
(
'LATITUDE', -90, 90, 0.5 
)
),
8307 -- SRID value for specifying a geodetic coordinate system
);
commit;

drop index gps_station_sidx;
CREATE INDEX gps_station_sidx ON gps_station(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=POINT');
drop index gps_lightin_sidx;
CREATE INDEX gps_lightin_sidx ON gps_lightin(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=POINT');
drop index gps_trek_sidx;
CREATE INDEX gps_trek_sidx ON gps_trek(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=LINE');


SELECT distinct SDO_GEOM.VALIDATE_GEOMETRY_WITH_CONTEXT(geom, 0.1)
from gps_station;

SELECT distinct SDO_GEOM.VALIDATE_GEOMETRY_WITH_CONTEXT(geom, 0.1)
from gps_lightin;

SELECT distinct header, SDO_GEOM.VALIDATE_GEOMETRY_WITH_CONTEXT(geom, 0.01)
from gps_trek;
/*
ORA-13356:
adjacent points in a geometry are redundant

#Участок движения - Лозова-Харків-К.Лопань, трек    13356 [Element <1>] [Coordinate <435>]
#Участок движения - Знам-Долинс-Херсон-Вадим, трек  13356 [Element <1>] [Coordinate <3>]  
#Участок движения - Львiв-Мостиська2, трек          13356 [Element <1>] [Coordinate <3>]  
#Участок движения - К.Лопань -Харків-Лозова, трек   13356 [Element <1>] [Coordinate <171>]
#Участок движения - Вадим-Джанкой, трек             13356 [Element <1>] [Coordinate <1>]  
*/

update gps_trek set geom = SDO_UTIL.REMOVE_DUPLICATE_VERTICES(geom,0.01);
commit;
