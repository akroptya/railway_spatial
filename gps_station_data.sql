-- Table for station coordinates
CREATE TABLE raw_gps_station_data
    (full_name                      VARCHAR2(3000 BYTE),
    header                         VARCHAR2(1000 BYTE),
    pp                             NUMBER,
    kod                            VARCHAR2(200 BYTE),
    lon                            NUMBER,
    lat                            NUMBER,
    height                         VARCHAR2(5 BYTE),
    name                           VARCHAR2(1000 BYTE),
    koordinata                     NUMBER,
    nmea                           VARCHAR2(1000 BYTE));

-- break tracks on links between stations

declare
   v_vertices MDSYS.VERTEX_SET_TYPE;
   v_track SDO_GEOMETRY;
   v_ord MDSYS.SDO_ORDINATE_ARRAY := null;
   v_esr_start varchar2(6);  
begin
    -- loop by processing tracks 
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
			SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=200 UNIT=M')='TRUE') st
        ))
		where mindist_id = dist
		order by id) loop
		    if (k.dist = k.mindist) then
			       -- take a station instead of this point, it is an end of previous link and start for next	
				
				if (v_ord is not null) then
					-- if previous track exists then it is an end and start
					-- write this link to table of links between stations
			    	v_ord.EXTEND(2);
					v_ord(v_ord.LAST - 1) := k.st_geom.SDO_POINT.x;
					v_ord(v_ord.LAST) := k.st_geom.SDO_POINT.y;	
					insert into kuski values 
					(c_trek.id, v_esr_start, k.k_esr,
					    SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),v_ord));
					commit;
				end if;
				-- if it is start of next (first) link, st_geom is it's first point
				v_esr_start := k.k_esr;
				v_ord := MDSYS.SDO_ORDINATE_ARRAY();
			    v_ord.EXTEND(2);
				v_ord(v_ord.LAST - 1) := k.st_geom.SDO_POINT.x;
				v_ord(v_ord.LAST) := k.st_geom.SDO_POINT.y;								
			else
			    -- intermediate point
			    -- if process of creating link is already started than add this point
			    -- else this point is not usefull 
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





----------------------------------------------------------------------------------------------
drop table stage1;
--create table stage1 as
insert into gps_esr
select distinct  
avg(floor(LON/100.0)+((LON-floor(LON/100.0)*100)/60.0)) lon, 
avg(floor(LAT/100.0)+((LAT-floor(LAT/100.0)*100)/60.0)) lat, 
b.K_ESR
from raw_gps_station_data a, klasstan@uzc1 b
where 
(replace(replace(replace(replace(upper(a.NAME),'Т',''),'''',''),' ',''),'.','') 
= replace(replace(replace(replace(b.NU_STANS,'Т',''),'''',''),' ',''),'.','')
or
replace(replace(replace(replace(upper(a.NAME),'Т',''),'''',''),' ',''),'.','') 
= replace(replace(replace(replace(b.NU_STAN,'Т',''),'''',''),' ',''),'.','')
or
replace(replace(replace(replace(upper(a.NAME),'Т',''),'''',''),' ',''),'.','') 
= replace(replace(replace(replace(b.N_STANS,'Т',''),'''',''),' ',''),'.','')
or
replace(replace(replace(replace(upper(a.NAME),'Т',''),'''',''),' ',''),'.','') 
= replace(replace(replace(replace(b.N_STAN,'Т',''),'''',''),' ',''),'.','')
)
and
case
     when FULL_NAME like '%ѕ≥вденно-«ах≥дна%' then 32
     when FULL_NAME like '%Ћьв≥вська%' then 35
     when FULL_NAME like '%ќдеська%' then 40     
     when FULL_NAME like '%ѕ≥вденна%' then 43     
     when FULL_NAME like '%ѕридн≥провська%' then 45    
     when FULL_NAME like '%ƒонецька%' then 48                    
     else 0
end = b.k_dor
and b.K_ADM=22
group by b.K_ESR
;

select * from gps_esr;

CREATE TABLE gps_esr
    (lon                            NUMBER,
    lat                            NUMBER,
    k_esr                          CHAR(6 BYTE));

insert into gps_esr select * from gps_esr@dl_vpea
where K_ESR not in (select K_ESR from gps_esr) ;
commit;

