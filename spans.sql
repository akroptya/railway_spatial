
create table GPS_TREK as select * from GPS_TREK@dl_vpea;

INSERT INTO USER_SDO_GEOM_METADATA VALUES
(
'GPS_TREK',  
'GEOM',        
SDO_DIM_ARRAY  
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
'LATITUDE', 
-90, 
90, 
0.5 
)
),
8307 -- SRID value for specifying a geodetic coordinate system
);
commit;
CREATE INDEX gps_trek_sidx ON gps_trek(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=LINE');

SELECT distinct header, SDO_GEOM.VALIDATE_GEOMETRY_WITH_CONTEXT(geom, 0.01)
from gps_trek;

insert into gps_trek
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
            cast(ordinates as SDO_ORDINATE_ARRAY)) geom,
			721+rownum
from
(select pp,max_pp, HEADER, 
    LineOrdinates(lon_lat(lon, lat)) over (partition by HEADER order by pp)  ordinates
from (select header, round(floor(lon/100.0)+((lon-floor(lon/100.0)*100)/60.0),6) lon, 
                     round(floor(lat/100.0)+((lat-floor(lat/100.0)*100)/60.0),6) lat,
                     pp, max(pp) over (partition by header) max_pp
from RAW_GPS_TREK_DATA
where full_name like 'D:\Work\gps\data\hartep\2%'
	   and substr(HEADER,1,instr(header,', тр')) not in
(select substr(HEADER,1,instr(header,', тр'))
FROM gps_trek)
order by HEADER, PP))
where pp = max_pp;

update gps_trek set geom = SDO_UTIL.REMOVE_DUPLICATE_VERTICES(geom,0.01);
commit;

SELECT distinct header, SDO_GEOM.VALIDATE_GEOMETRY_WITH_CONTEXT(geom, 0.01)
from gps_trek;

create table gps_station (K_ESR primary key, 
K_DOR,K_ADM,K_OTD,NU_STAN, NU_STANS,
GEOM)
 as
select a.K_ESR , K_DOR,K_ADM,K_OTD,NU_STAN, NU_STANS,
       SDO_GEOMETRY(
            2001, -- SDO_GTYPE format: D00T.two-dimension point
            8307, -- SDO_SRID (geodetic)
            SDO_POINT_TYPE(
            b.LON, -- Longitude
            b.LAT, -- Latitude
            NULL -- without third dimension (do we need height?)
            ),
            NULL,
            NULL    
       )    
from klasstan@uzc1 a  join gps_esr b on a.K_ESR = b.K_ESR;


INSERT INTO USER_SDO_GEOM_METADATA VALUES
(
'GPS_STATION',  
'GEOM',         
SDO_DIM_ARRAY   
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
'LATITUDE', -- DIMENSION NAME for second dimension
-90, -- SDO_LB for the dimension
90, -- SDO_UB for the dimension
0.5 -- Tolerance of 0.5 meters
)
),
8307 -- SRID value for specifying a geodetic coordinate system
);
commit;

CREATE INDEX gps_station_sidx ON gps_station(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=POINT');


create table gps_all_station (NU_STAN, K_DOR, GEOM)
 as
select NAME, zal,
       SDO_GEOMETRY(
            2001, -- SDO_GTYPE format: D00T.two-dimension point
            8307, -- SDO_SRID (geodetic)
            SDO_POINT_TYPE(
            LON, 
            LAT, 
            NULL 
            ),
            NULL,
            NULL    
       )    
from (select a.NAME,
case
     when FULL_NAME like '%П_вденно-Зах_дна%' then 32
     when FULL_NAME like '%Льв_вська%' then 35
     when FULL_NAME like '%Одеська%' then 40     
     when FULL_NAME like '%П_вденна%' then 43     
     when FULL_NAME like '%Придн_провська%' then 45    
     when FULL_NAME like '%Донецька%' then 48                    
     else 0
end zal,
avg(floor(LON/100.0)+((LON-floor(LON/100.0)*100)/60.0)) lon, 
avg(floor(LAT/100.0)+((LAT-floor(LAT/100.0)*100)/60.0)) lat 
from raw_gps_station_data a
where NAME not like 'ЕЦ%'
group by a.NAME,
case
     when FULL_NAME like '%П_вденно-Зах_дна%' then 32
     when FULL_NAME like '%Льв_вська%' then 35
     when FULL_NAME like '%Одеська%' then 40     
     when FULL_NAME like '%П_вденна%' then 43     
     when FULL_NAME like '%Придн_провська%' then 45    
     when FULL_NAME like '%Донецька%' then 48                    
     else 0
end);

INSERT INTO USER_SDO_GEOM_METADATA VALUES
('GPS_ALL_STATION',  
'GEOM',SDO_DIM_ARRAY(SDO_DIM_ELEMENT('LONGITUDE',-180, 180, 0.5 ),
SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.5)),8307);
commit;

CREATE INDEX GPS_ALL_STATION_sidx ON GPS_ALL_STATION(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=POINT');


--  Tracks from second stage

/*
SDO_GEOM Package (Geometry)
http://10.1.100.7/oracle/db1211/E16655_01/appdev.121/e17896/sdo_objgeom.htm#i865398

SDO_GEOM.SDO_CLOSEST_POINTS
Computes the minimum distance between two geometries and the points 
(one on each geometry) that are the minimum distance apart.

SDO_GEOM.SDO_LENGTH
Computes the length or perimeter of a geometry.

SDO_UTIL.EXTRACT
Returns the two-dimensional geometry that represents a specified element 
(and optionally a ring) of the input two-dimensional geometry.

SDO_UTIL.EXTRACT_ALL
Returns all elements and subelements of the input two-dimensional geometry, 
as an array of one or more geometries.

SDO_UTIL.GETNUMVERTICES
Returns the number of vertices in the input geometry.
SDO_UTIL.GETVERTICES
Returns the coordinates of the vertices of the input geometry.

*/

/* associate stations with tracks (300 meters near) */

SELECT SDO_GEOM.SDO_DISTANCE(a.geom, b.geom, 0.5, ' UNIT=METER ') dist,       
        b.k_esr, a.* 
FROM GPS_TREK a, gps_station b
WHERE 
SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=300 UNIT=M')='TRUE'
order by  HEADER
;


SELECT b.k_esr, SDO_GEOM.SDO_DISTANCE(a.geom, b.geom, 0.5, ' UNIT=METER ') dist, 
b.geom.SDO_POINT.X x, b.geom.SDO_POINT.y y
FROM GPS_TREK a, gps_station b
WHERE 
a.HEADER = '#Участок движения - Харк_в-Люб-ПолтаваК-Греб, трек 1' and
SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=300 UNIT=M')='TRUE';


create table kuski (id number, esr_start varchar2(6), 
esr_finish varchar2(6), geom SDO_GEOMETRY);


INSERT INTO USER_SDO_GEOM_METADATA VALUES
(
'KUSKI','GEOM',  SDO_DIM_ARRAY
(
SDO_DIM_ELEMENT
(
'LONGITUDE', -180,        180,         0.5          
),
SDO_DIM_ELEMENT
('LATITUDE',  -90, 90, 0.5 )
),
8307 -- SRID value for specifying a geodetic coordinate system
);
commit;

CREATE INDEX kuski_sidx ON kuski(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=LINE');


create table kuski_all (id number, esr_start varchar2(60), 
esr_finish varchar2(60), geom SDO_GEOMETRY);


-- 0. list of points on track by moving order
-- 1. list of stations on track by moving order
-- 2. find links between stations
-- 3. check atomic property of links 
-- 4. for nonatomic links calculate coordinates of intermediate stations
-- * only for detailed track we can calculate coordinates of intermediate stations

-- in any case use center of stations instead of first point on a track (as it is too expensive for calculating distances)

create table kuski_20140521 as select * from kuski;
delete kuski;
select * from kuski where id = 204;
declare
   v_vertices MDSYS.VERTEX_SET_TYPE;
   v_track SDO_GEOMETRY;
   v_ord MDSYS.SDO_ORDINATE_ARRAY := null;
   v_esr_start varchar2(6);  
begin
    -- цикл по трекам которые надо отработать
	for c_trek in (select a.id, a.geom --into v_id, v_track
				FROM GPS_TREK a) loop
--	v_vertices := 
	for k in (
	   select id, x, y, 
	   		  case when mindist_esr = dist then k_esr else null end k_esr, 
			  case when mindist_esr = dist then st_geom else null end st_geom, 
			  dist, mindist_esr mindist
	   from
	   (select id, x, y, k_esr, st_geom, dist,
	          min(dist) over (partition by k_esr) mindist_esr,
			  min(dist) over (partition by id) mindist_id
	   from  
	   (select tr.id, tr.x, tr.y, 
	          st.k_esr, st.geom st_geom,
			  SDO_GEOM.SDO_DISTANCE(tr.geom, st.geom, 0.5, ' UNIT=METER ') dist	      
	    from 
	   (select id, x, y, SDO_GEOMETRY(2001,8307,SDO_POINT_TYPE(x, y, null),null,null) geom
		from TABLE(SDO_UTIL.GETVERTICES(c_trek.geom))) tr,
		(SELECT b.id k_esr, b.geom
		FROM GPS_TREK a, SEPARATION_STATIONS_geom b 
		WHERE 
			a.id = c_trek.id and
			SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=400 UNIT=M')='TRUE') st
        ))
		where mindist_id = dist
		order by id) loop
		    if (k.dist = k.mindist) then
				-- вместо этой точки берём станцию, это конец предыдущего участка между станциями и начало нового
				
				if (v_ord is not null) then
					-- если был предыдущий трек, то это конец и начало
					-- записываем в таблицу участков этот кусочек трека
			    	v_ord.EXTEND(2);
					v_ord(v_ord.LAST - 1) := k.st_geom.SDO_POINT.x;
					v_ord(v_ord.LAST) := k.st_geom.SDO_POINT.y;	
					insert into kuski values 
					(c_trek.id, v_esr_start, k.k_esr,
					    SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),v_ord));
					commit;
				end if;
				-- если это начало следующего (первого) участка, st_geom его первая точка
				v_esr_start := k.k_esr;
				v_ord := MDSYS.SDO_ORDINATE_ARRAY();
			    v_ord.EXTEND(2);
				v_ord(v_ord.LAST - 1) := k.st_geom.SDO_POINT.x;
				v_ord(v_ord.LAST) := k.st_geom.SDO_POINT.y;								
			else
			    -- это промежуточная точка
				-- если участок уже начал формироваться, то точка дописывается в него
				-- иначе точка не нужна 
				if (v_ord is not null) then
				    v_ord.EXTEND(2);
					v_ord(v_ord.LAST - 1) := k.x;
					v_ord(v_ord.LAST) := k.y;													
				end if;
			end if;
		--	dbms_output.put_line(k.id||' '||k.k_esr||' '||k.dist||' '||k.mindist);
	end loop;
	end loop;
end;	 
commit;
rollback;

-- 2311 still need to be determined
select count(*)
from GAS_RAILWAY.SPANS sp, gas_railway.segmentrails st 
where st.segmentid = SP.id and st.DIRECTION in (0,1);	  

drop table gps_station_k_esr;
create table gps_station_k_esr (id primary key, k_esr ) organization index 
as select ss1.ID, k_esr from gps_station s, GAS_RAILWAY.SEPARATION_STATIONS ss1
where s.k_esr = ss1.code;


-- 325 pairs, potentially 650 spans
select count(*)
from GAS_RAILWAY.SPANS sp1, GAS_RAILWAY.SPANS sp2
where sp1.FINISHSPID = sp2.STARTSPID and
      sp1.STARTSPID in (select id from gps_station_k_esr) and
	  sp2.FINISHSPID in (select id from gps_station_k_esr) and
	  sp1.FINISHSPID not in (select id from gps_station_k_esr);
;

-- 653, 
select count(*)
from GAS_RAILWAY.SPANS sp1, GAS_RAILWAY.SPANS sp2, GAS_RAILWAY.SPANS sp3
where sp1.FINISHSPID = sp2.STARTSPID and
	  sp2.FINISHSPID = sp3.STARTSPID and
      sp1.STARTSPID in (select id from gps_station_k_esr) and
	  sp3.FINISHSPID in (select id from gps_station_k_esr) and
	  (sp1.FINISHSPID not in (select id from gps_station_k_esr)
	  or
	  sp2.FINISHSPID not in (select id from gps_station_k_esr)
	  );

-- 1009
select count(*)
from GAS_RAILWAY.SPANS sp1, GAS_RAILWAY.SPANS sp2, GAS_RAILWAY.SPANS sp3, 
	 GAS_RAILWAY.SPANS sp4
where sp1.FINISHSPID = sp2.STARTSPID and
	  sp2.FINISHSPID = sp3.STARTSPID and
	  sp2.FINISHSPID = sp4.STARTSPID and	  
      sp1.STARTSPID in (select id from gps_station_k_esr) and
	  sp4.FINISHSPID in (select id from gps_station_k_esr) and
	  (sp1.FINISHSPID not in (select id from gps_station_k_esr)
	  or
	  sp2.FINISHSPID not in (select id from gps_station_k_esr)
	  or
	  sp3.FINISHSPID not in (select id from gps_station_k_esr)	  
	  );


select * from kuski;
create table kuski_id (id_start, id_finish, id_kuski, ESR_START, ESR_FINISH, GEOM
primary key(id_start, id_finish, id_kuski)) organization index as
select distinct ss1.ID id_start, ss2.ID id_finish, s.id id_kuski
from kuski s, GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2
where s.ESR_START = ss1.code and s.ESR_FINISH = ss2.code;

select ss1.id, ss2.id, SDO_GEOM.SDO_LENGTH(k.geom, m.diminfo), k.*
from kuski k,
	 GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2,      
	 GAS_RAILWAY.SPANS SP, 
	 user_sdo_geom_metadata m 
where k.ESR_START = ss1.code and k.ESR_FINISH = ss2.code and
	  SP.STARTSPID(+) = ss1.id and SP.FINISHSPID(+) = ss2.id and SP.STARTSPID is null
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM';

-- 10043	10228
select FINISHSPID, LENGTH
from GAS_RAILWAY.SPANS sp, gas_railway.segmentrails st  
where STARTSPID = 10043 and st.segmentid = SP.id and st.DIRECTION in (0,1);
select STARTSPID, LENGTH
from GAS_RAILWAY.SPANS sp, gas_railway.segmentrails st 
where FINISHSPID = 10228 and st.segmentid = SP.id and st.DIRECTION in (0,1);

select s.STARTSPID, f.FINISHSPID, s.length + f.length LENGTH
from
(select FINISHSPID STARTSPID, LENGTH
from GAS_RAILWAY.SPANS sp, gas_railway.segmentrails st  
where STARTSPID = 10043 and st.segmentid = SP.id and st.DIRECTION in (0,1)) s,
(select STARTSPID FINISHSPID, LENGTH
from GAS_RAILWAY.SPANS sp, gas_railway.segmentrails st 
where FINISHSPID = 10228 and st.segmentid = SP.id and st.DIRECTION in (0,1)) f
where s.length + f.length < 11249*1.1;

select s.STARTSPID, f.FINISHSPID, 
	   case when s.STARTSPID = 10045 then s.length
	   		else s.length + f.length
	   end+8301  LENGTH
from
(select FINISHSPID STARTSPID, LENGTH
from GAS_RAILWAY.SPANS sp, gas_railway.segmentrails st  
where STARTSPID = 10044 and st.segmentid = SP.id and st.DIRECTION in (0,1)) s,
(select STARTSPID FINISHSPID, LENGTH
from GAS_RAILWAY.SPANS sp, gas_railway.segmentrails st 
where FINISHSPID = 10045 and st.segmentid = SP.id and st.DIRECTION in (0,1)) f
where s.length + f.length < 11249*1.1;

-- on good tracks algorithm provides station's coordinates and tacks links for spans from gas_railway

select SDO_GEOM.SDO_LENGTH(k.geom, m.diminfo), k.* 
from kuski k, user_sdo_geom_metadata m
where m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
and ESR_START = 467004 and ESR_FINISH = 467305;
;


-- 240
select st1.length, SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo), k1.geom, sp1.FINISHSPID, k.* 
from GAS_RAILWAY.SPANS sp1, gas_railway.segmentrails st1,
     GAS_RAILWAY.SPANS sp2, gas_railway.segmentrails st2,
	 kuski_id k, kuski k1, user_sdo_geom_metadata m
where sp1.FINISHSPID = sp2.STARTSPID and
      sp1.STARTSPID = k.id_start and
	  sp2.FINISHSPID = k.id_finish and
	  sp1.FINISHSPID not in (select id from gps_station_k_esr) and
	  st1.segmentid = sp1.id and st1.DIRECTION in (0,1) and
	  st2.segmentid = sp2.id and st2.DIRECTION in (0,1)
	  and k.id_kuski = k1.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) 
	  between (st1.LENGTH+st2.LENGTH-200) and (st1.LENGTH+st2.LENGTH+200)
	  ;

select *
from gps_all_station a
WHERE 
	SDO_WITHIN_DISTANCE(a.geom, SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(25.90904414973,
49.1955981949,NULL),NULL,NULL), 
'DISTANCE=300 UNIT=M')='TRUE'
;

declare
   v_track SDO_GEOMETRY;
   v_track_before SDO_GEOMETRY;   
   v_track_after SDO_GEOMETRY;      

   v_point SDO_GEOMETRY;

   v_vertices MDSYS.VERTEX_SET_TYPE;
   v_ord MDSYS.SDO_ORDINATE_ARRAY := null;
   v_esr_start varchar2(6);  
begin
    for k in (select st1.length, k1.geom,
				sp1.STARTSPID STARTSPID1, sp1.FINISHSPID FINISHSPID1,
				sp2.STARTSPID STARTSPID2, sp2.FINISHSPID FINISHSPID2
		from GAS_RAILWAY.SPANS sp1, gas_railway.segmentrails st1,
		     GAS_RAILWAY.SPANS sp2, gas_railway.segmentrails st2,
	 		kuski_id k, kuski k1, user_sdo_geom_metadata m
		where sp1.FINISHSPID = sp2.STARTSPID and
      sp1.STARTSPID = k.id_start and
	  sp2.FINISHSPID = k.id_finish and
	  sp1.FINISHSPID not in (select id from gps_station_k_esr) and
	  st1.segmentid = sp1.id and st1.DIRECTION in (0,1) and
	  st2.segmentid = sp2.id and st2.DIRECTION in (0,1)
	  and k.id_kuski = k1.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) 
	  between (st1.LENGTH+st2.LENGTH-200) and (st1.LENGTH+st2.LENGTH+200)
	  and rownum < 10) loop

	split_line_l(k.geom, k.length,
		v_point, 
		v_track_before,  
		v_track_after);
	dbms_output.put_line(v_point.SDO_POINT.x);		
	dbms_output.put_line(v_point.SDO_POINT.y);	
	dbms_output.put_line(SDO_GEOM.SDO_DISTANCE(v_point, v_track, 0.5, ' UNIT=METER '));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(k.geom));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(v_track_before));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(v_track_after));

    end loop;	  

end;	  
