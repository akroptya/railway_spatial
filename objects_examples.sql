-- lightins not far than 1km from center of station
SELECT SDO_GEOM.SDO_DISTANCE(a.geom, b.geom, 0.5, ' UNIT=METER ') dist,
        a.*, b.*
FROM gps_lightin a, gps_station b
WHERE 
SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=1 UNIT=KM')='TRUE' 
;

-- nearest lightins but not far han 1km from center of station
SELECT SDO_NN_DISTANCE(1) dist , -- distance in meters
        a.*, b.*
FROM gps_station a, gps_lightin b
WHERE 
b.NAME like 'Ч%' and
SDO_NN(a.geom, b.geom, 'SDO_NUM_RES=1 DISTANCE=1000',1)='TRUE' 
;

-- 2 lights nearest to a specific station
SELECT  SDO_NN_DISTANCE(1) dist, 
        a.*, b.*
FROM gps_station a, gps_lightin b
WHERE 
a.k_esr = '320219' and
SDO_NN(b.geom, a.geom, 'SDO_NUM_RES=2',1)='TRUE'
;

-- 2 nearest stations to the point with GPS coordinates
select SDO_NN_DISTANCE(1) dist,         a.*
FROM gps_station a
WHERE 
SDO_NN(a.geom, 
       SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(29.29631,50.77983,NULL),NULL,NULL), 
       'SDO_NUM_RES=2',1)='TRUE'
;

-- nearest track for a point 
select SDO_NN_DISTANCE(1) dist,
        a.*
FROM gps_trek a
WHERE 
SDO_NN(a.geom, 
       SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(29.29631,50.77983,NULL),NULL,NULL), 
       'SDO_NUM_RES=1',1)='TRUE'
;


-- Point on track 
-- 1. 100 meters buffer areas around tracks
create table gps_trek_buff100 as
select SDO_GEOM.SDO_BUFFER(tr.geom, 100, 0.5) buff_geom,
       tr.* 
from gps_trek tr;
INSERT INTO USER_SDO_GEOM_METADATA
    SELECT 'GPS_TREK_BUFF100','BUFF_GEOM', DIMINFO, SRID
    FROM USER_SDO_GEOM_METADATA
    WHERE TABLE_NAME='GPS_TREK';
CREATE INDEX gps_trek_buff100_sidx ON gps_trek_buff100(buff_geom) 
INDEXTYPE IS MDSYS.SPATIAL_INDEX;

select a.*
FROM gps_trek_buff100 a
WHERE 
SDO_FILTER(a.buff_geom, 
       SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(45.70945,34.38717,NULL),NULL,NULL))='TRUE'
;

-- tracks intersection
-- 19 sec ! - slow
select a.*, b.*
FROM gps_trek a, gps_trek b
WHERE SDO_OVERLAPBDYDISJOINT (a.geom, b.geom) = 'TRUE';

-- distance from station to track
select SDO_GEOM.SDO_DISTANCE(a.geom, b.geom,0.5,'unit=km') dist,
   b.*, a.*
FROM gps_station a, gps_trek b
WHERE N_STAN = 'КИЕВ-ПАССАЖИРСКИЙ'
order by 1 asc;

-- length of track
select SDO_GEOM.SDO_LENGTH(b.geom, 0.5, 'unit=KM'), b.*
FROM gps_trek b;

-- Nearest point laying on track
declare
 v_pt1 SDO_GEOMETRY;
 v_pt2 SDO_GEOMETRY;
 v_dist NUMBER;
begin
    for track in (select b.geom, b.header
              from gps_trek b 
              where b.header = '#Участок движения - Севаст-Сімф-Запоріжжя1-Лозова, трек') loop

        for stant in (select SDO_GEOM.SDO_DISTANCE(a.geom, track.geom,0.5,'unit=km') dist,
        a.*, track.header
        FROM gps_station a
        where SDO_WITHIN_DISTANCE(a.geom, track.geom, 'DISTANCE=1 UNIT=KM')='TRUE' 
        order by 1 asc) loop            
SDO_GEOM.SDO_CLOSEST_POINTS(GEOM1=>track.geom,GEOM2=>stant.geom,
tolerance=>0.5,UNIT=>'UNIT=METER', 
dist=>v_dist,GEOMA=>v_pt1,GEOMB=>v_pt2);
--SDO_GEOM.sdo_closest_points(GEOM1=>?, GEOM2=>?, TOLERANCE=>?, UNIT=>?, DIST=>?, GEOMA=>?, GEOMB=>?)
dbms_output.put_line(stant.dist||' '||v_dist||' '||stant.NU_STAN||' '||stant.header);
dbms_output.put_line('Точка на треку:' ||
TO_CHAR(v_pt1.sdo_point.x) || ', ' ||
TO_CHAR(v_pt1.sdo_point.y));
        end loop;            
    end loop;              
end;

/*
1. Choose track and find on it points for stations
2. Represent track like an array of verticies
3. For every pair of verticies build a line and search for station on this line
4. as a result we have link between stations with all intermediate verticies from track, so we have line object for a span   
*/

-- Nearest points on track
-- 1. where station is actually on track with some errors in measurements
-- 2. with real coordinates from vehicles we can adance our tracks in future
-- station should not be far than 1km from tack 
-- we need a function that return all verticies from track between two points given as parameters
-- method to determine order of points on track


select SDO_GEOM.SDO_DISTANCE(a.geom, b.geom,0.5,'unit=km') dist,
   b.*, a.*
FROM gps_station a, gps_trek b
--WHERE N_STAN = 'КИЕВ-ПАССАЖИРСКИЙ'
where SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=1 UNIT=KM')='TRUE' 
order by 1 asc;






