-- 11.06.2014 Creating representation of railway network a set of spatial pieces between "connectors"

select min(b.id) id, a.TIMESTAMP 
from
(select 
	TMS.TIMESTAMP,
	mdsys.sdo_geometry(2001,8307,mdsys.sdo_point_type(LON/10000000,LAT/10000000,null),null,null) geom,	
	TMS.SPEED
from TELEM.TRACKER_DATA@dl_vpnsi tms
where tms.imei = '12207006419870'	              
and TMS.PART between to_char(sysdate,'dd') and to_char(sysdate,'dd')
and TMS.TIMESTAMP between sysdate-10/24 and sysdate-1/24
and SPEED != 0) a left outer join 
segmentrails_geom b 
on SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=400 UNIT=M')='TRUE'
group by a.TIMESTAMP
;

select 	st1.ts,
		ss1.NAME||'('||ss1.CODE||')' station1, 
		ss2.NAME||'('||ss2.CODE||')' station2,
		st1.id 
from		
(select min(b.id) id, a.TIMESTAMP ts
from
(select 
	TMS.TIMESTAMP,
	mdsys.sdo_geometry(2001,8307,mdsys.sdo_point_type(LON/10000000,LAT/10000000,null),null,null) geom,	
	TMS.SPEED
from TELEM.TRACKER_DATA@dl_vpnsi tms
where tms.imei = '12207006419870'	              
and TMS.PART between to_char(sysdate,'dd') and to_char(sysdate,'dd')
and TMS.TIMESTAMP between sysdate-10/24 and sysdate-1/24
and SPEED != 0) a left outer join 
segmentrails_geom b 
on SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=400 UNIT=M')='TRUE'
group by a.TIMESTAMP) st1
left outer join GAS_RAILWAY.segmentrails st on st1.id= st.id
left outer join GAS_RAILWAY.SPANS sp on st.SEGMENTID = sp.id
left outer join GAS_RAILWAY.SEPARATION_STATIONS ss1 on sp.STARTSPID = ss1.id
left outer join GAS_RAILWAY.SEPARATION_STATIONS ss2 on sp.FINISHSPID = ss2.id
order by ts;

select 	st1.ts, dist, NAME_TXT, SOURCE_TYPE, START_,
		st1.id,
		(case when direction = 2 then -1 else 1 end) *(SUM (START_-START_lag)
        OVER (PARTITION BY ID ORDER BY TS ROWS 10 PRECEDING))
from		
(select b.RAILID id, a.TIMESTAMP ts, NAME_TXT, SOURCE_TYPE, START_,
	SDO_GEOM.SDO_DISTANCE(a.geom, b.geom, 0.5, ' UNIT=METER ') dist,
	lag(START_,1,0) over (partition by b.RAILID order by TIMESTAMP) START_lag,
	b.direction
from
(select 
	TMS.TIMESTAMP,
	mdsys.sdo_geometry(2001,8307,mdsys.sdo_point_type(LON/10000000,LAT/10000000,null),null,null) geom,	
	TMS.SPEED
from TELEM.TRACKER_DATA@dl_vpnsi tms
where tms.imei = '12896004335318'	              
and TMS.PART between to_char(sysdate,'dd') and to_char(sysdate,'dd')
and TMS.TIMESTAMP between sysdate-3/24 and sysdate-1/24
and SPEED != 0) a left outer join 
railid_gps_pseudo b  
on 
-- SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=400 UNIT=M')='TRUE'
SDO_NN(b.geom, a.geom, 'SDO_NUM_RES=2 DISTANCE=100',1)='TRUE' 
) st1
order by ts;

commit;

select *
from RAIL_pseudo_JOINTS;
alter table RAIL_pseudo_JOINTS add (koordm number);
update RAIL_pseudo_JOINTS a set a.koordm = (select a.START_ + b.KILOMETERAGESTART
from gas_railway.railkilometerage b where b.RAILID = a.RAILID and b.KILOMETERAGELNO = 0)
;

alter table railid_gps_pseudo add (koordm number);
update railid_gps_pseudo a set a.koordm = (select b.koordm
from RAIL_pseudo_JOINTS b where b.RAILID = a.RAILID and a.START_ = b.START_ and
rownum < 2)
;
commit;

select a.RAILID, START_,  d.name name_txt, 'ізол.стик' source_type, 
		b.KILOMETERAGESTART, st.direction
from GAS_RAILWAY.RAILISOLATIONJOINTS a,
	 gas_railway.sg_isolation_joint_types d,
	 gas_railway.railkilometerage b,
	 gas_railway.segmentrails st 		 
where 
	 d.id = case when st.DIRECTION = 2 then a.INDIRECTTYPE else a.DIRECTTYPE end and
	 a.railid = b.railid and  a.railid=st.id;

with t as (select id as pp, 
	         			SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(x,y,NULL),NULL,NULL) geom, x, y
	         			from table(						
						select sdo_util.getvertices(geom) from segmentrails_geom 
						where id = 15817 and rownum < 2))
			select  t2.pp, t1.x t1x, t1.y t1y, t2.x t2x, t2.y t2y,
				    t2.geom t2geom, t1.geom t1geom,
					SDO_GEOM.SDO_DISTANCE(t2.geom, t1.geom, 1, ' UNIT=M ') rasst_points,
					sum(SDO_GEOM.SDO_DISTANCE(t2.geom, t1.geom, 1, ' UNIT=M ')) over 
					(order by t1.pp ROWS UNBOUNDED PRECEDING) rasst 		
			from t t1, t t2 
			where (t1.pp = t2.pp-1 and t1.pp!=1) or (t1.pp=1 and t2.pp=1)
			order by t1.pp	;
			
	select START_, 
	       lead(START_,1,100000) over (order by START_) START_next,
	       name_txt, source_type,
		   START__, direction, b.kilometeragestart
	from (select RAILID, 
	case when direction = 2 then ST_LENGTH-START_ else START_ end START_, 
	to_Char(LISTAGG(NAME_TXT, ',') WITHIN GROUP (ORDER BY source_type desc)) NAME_TXT,
	to_Char(LISTAGG(SOURCE_TYPE, ',') WITHIN GROUP (ORDER BY source_type desc) ) source_type,
	START_ START__, direction
	from RAIL_pseudo_JOINTS
	group by RAILID, START_, 
	(case when direction = 2 then ST_LENGTH-START_ else START_ end),
	 direction) a,
		 gas_railway.railkilometerage b	
	where a.railid = 15817 and b.railid = 15817 
	order by START_;

select * from
(select RAILID, 
	case when direction = 2 then ST_LENGTH-START_ else START_ end START_, 
	to_Char(LISTAGG(NAME_TXT, ',') WITHIN GROUP (ORDER BY source_type desc)) NAME_TXT,
	to_Char(LISTAGG(SOURCE_TYPE, ',') WITHIN GROUP (ORDER BY source_type desc) ) source_type,
	START_ START__, direction
	from RAIL_pseudo_JOINTS
	group by RAILID, START_, 
	(case when direction = 2 then ST_LENGTH-START_ else START_ end),
	 direction) a
where a.railid = 15817;	

select * from gas_railway.railkilometerage b where b.railid = 15817;
select *
from
(select RAILID, count(distinct KILOMETERAGELNO) 
from gas_railway.railkilometerage b group by RAILID
having count(distinct KILOMETERAGELNO) > 1) where railid not in (select railid from gas_railway.railkilometerage where KILOMETERAGELNO=0);
-- and b.KILOMETERAGELNO = 0

drop table RAIL_pseudo_JOINTS; 
create table RAIL_pseudo_JOINTS as
select 	RAILID, START_, name_txt,source_type, KILOMETERAGESTART, direction,
		st_LENGTH  
from
(select a.RAILID, START_,  d.name name_txt, 'ізол.стик' source_type, 
		b.KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH
from GAS_RAILWAY.RAILISOLATIONJOINTS a,
	 gas_railway.sg_isolation_joint_types d,
	 gas_railway.railkilometerage b,
	 gas_railway.segmentrails st 		 
where 
	 d.id = case when st.DIRECTION = 2 then a.INDIRECTTYPE else a.DIRECTTYPE end and
	 a.railid = b.railid and  a.railid=st.id --and st.lno = b.kilometeragelno
	and b.KILOMETERAGELNO = 0	 
union all	
SELECT 	a.railid, a.coord, a.name, 'платформа' source_type, 
		km.KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH   
FROM gas_railway.railplatforms a, gas_railway.segmentrails st, 
	 gas_railway.RAILKILOMETERAGE km 
where 
	a.railid = st.id and st.id = km.RAILID --and st.lno = km.kilometeragelno
	and km.KILOMETERAGELNO = 0
union all
select 	st.id, 0, ss.CODE||' '||ss.NAME, 'вісь станції' source_type, 
		KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH
from GAS_RAILWAY.SPANS SP, gas_railway.segmentrails st,
GAS_RAILWAY.SEPARATION_STATIONS ss, gas_railway.RAILKILOMETERAGE km 
where ss.ID = sp.STARTSPID
	and st.segmentid = SP.id --and st.DIRECTION in (0,1)
	and st.id = km.RAILID --and st.lno = km.kilometeragelno
	and km.KILOMETERAGELNO = 0
union all
select 	st.id, LENGTH, ss.CODE||' '||ss.NAME, 'вісь станції' source_type, 
		KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH
from GAS_RAILWAY.SPANS SP, gas_railway.segmentrails st,
GAS_RAILWAY.SEPARATION_STATIONS ss, gas_railway.RAILKILOMETERAGE km 
where 
	ss.ID = sp.finishspid
	and st.segmentid = SP.id -- and st.DIRECTION in (2)
	and st.id = km.RAILID -- and st.lno = km.kilometeragelno
	and km.KILOMETERAGELNO = 0
union all
  select st.id, 0+sp.STARTSPLIMIT, 'межа права станції '||ss.NAME, 
  	'межа станції' source_type, KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH
from GAS_RAILWAY.SPANS SP, gas_railway.segmentrails st,
GAS_RAILWAY.SEPARATION_STATIONS ss, gas_railway.RAILKILOMETERAGE km 
where 
	ss.ID = sp.STARTSPID and
	st.segmentid = SP.id 
	and st.id = km.RAILID -- and st.lno = km.kilometeragelno
	and km.KILOMETERAGELNO = 0	
union all
  select st.id, abs(KILOMETERAGEFINISH-KILOMETERAGESTART)-sp.finishsplimit, 
  		'межа ліва станції '||ss.NAME, 'межа станції' source_type, 
  		KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH
from GAS_RAILWAY.SPANS SP, gas_railway.segmentrails st,
GAS_RAILWAY.SEPARATION_STATIONS ss, gas_railway.RAILKILOMETERAGE km
where ss.ID = sp.finishspid and
	st.segmentid = SP.id 
	and st.id = km.RAILID --and st.lno = km.kilometeragelno
	and km.KILOMETERAGELNO = 0	
union all
  select st.id, 0+sp.STARTSPSWITCHDISTANCE, 'стрілка станції '||ss.NAME, 
  	'стрілка' source_type, KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH
from GAS_RAILWAY.SPANS SP, gas_railway.segmentrails st,
GAS_RAILWAY.SEPARATION_STATIONS ss, gas_railway.RAILKILOMETERAGE km 
where 
	ss.ID = sp.STARTSPID and
	st.segmentid = SP.id 
	and st.id = km.RAILID -- and st.lno = km.kilometeragelno
	and km.KILOMETERAGELNO = 0	
union all
  select st.id, abs(KILOMETERAGEFINISH-KILOMETERAGESTART)-sp.FINISHSPSWITCHDISTANCE, 
  		'стрілка станції '||ss.NAME, 'стрілка' source_type, 
  		KILOMETERAGESTART, st.direction, st.LENGTH st_LENGTH
from GAS_RAILWAY.SPANS SP, gas_railway.segmentrails st,
GAS_RAILWAY.SEPARATION_STATIONS ss, gas_railway.RAILKILOMETERAGE km
where ss.ID = sp.finishspid and
	st.segmentid = SP.id 
	and st.id = km.RAILID --and st.lno = km.kilometeragelno
	and km.KILOMETERAGELNO = 0	
)
order by RAILID, start_;

create table railid_gps_pseudo (railid number, START_ number, name_txt VARCHAR2(200),
source_type VARCHAR2(100), geom SDO_GEOMETRY);

delete from USER_SDO_GEOM_METADATA where TABLE_NAME = 'RAILID_GPS_PSEUDO';
INSERT INTO USER_SDO_GEOM_METADATA VALUES
(
'RAILID_GPS_PSEUDO',  -- table name
'GEOM',         -- column name
SDO_DIM_ARRAY   -- attribute DIMINFO for measurement boaders and tolerance
(
SDO_DIM_ELEMENT
(
'LONGITUDE',    -- DIMENSION NAME for first dimension
-180,           -- SDO_LB for the dimension
180,            -- SDO_UB for the dimension
0.5             -- Tolerance of 0.5 meters
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

CREATE INDEX railid_gps_pseudo_sidx ON railid_gps_pseudo(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=LINE');

select * from segmentrails_geom a,
(select id, count(*) from segmentrails_geom
group by id having count(*) > 1) b
where a.id = b.id;
commit;

declare
    cursor c1 (p_railid number) is
	select START_, 
	       lead(START_,1,100000) over (order by START_) START_next,
	       name_txt, source_type,
		   START__, direction, b.kilometeragestart
	from (select RAILID, 
	case when direction = 2 then ST_LENGTH-START_ else START_ end START_, 
	to_Char(LISTAGG(NAME_TXT, ',') WITHIN GROUP (ORDER BY source_type desc)) NAME_TXT,
	to_Char(LISTAGG(SOURCE_TYPE, ',') WITHIN GROUP (ORDER BY source_type desc) ) source_type,
	START_ START__, direction
	from RAIL_pseudo_JOINTS
	group by RAILID, START_, 
	(case when direction = 2 then ST_LENGTH-START_ else START_ end),
	 direction) a,
		 gas_railway.railkilometerage b	
	where a.railid = p_railid and b.railid = p_railid and b.KILOMETERAGELNO = 0 
	order by START_;

	v_name_txt varchar2(300);
	v_source_type varchar2(200);

	v_track mdsys.sdo_geometry;
	v_target number;
	v_next number;
	v_start_ number;
	v_direction number;
	v_kilometeragestart number;
	 
	flag number := 0;
	v_railid number := 15663;
	split_rate number;		
	v_picket_line mdsys.sdo_geometry;
	v_ord MDSYS.SDO_ORDINATE_ARRAY;
	
	v_x1 number;
	v_y1 number;
	v_x2 number;
	v_y2 number;		
begin
   for rail in (select distinct id from segmentrails_geom) loop

	flag := 0;
	v_ord := MDSYS.SDO_ORDINATE_ARRAY();	
	v_railid := rail.id;

	open c1 (v_railid);
    fetch c1 into v_target, v_next, v_name_txt, v_source_type, v_start_, 
	v_direction, v_kilometeragestart;


	select 
		case when v_direction = 2 then SDO_UTIL.REVERSE_LINESTRING(geom) else geom end 
	into v_track 
	from segmentrails_geom where id = v_railid and rownum < 2;
	
	for k in (with t as (select id as pp, 
	         			SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(x,y,NULL),NULL,NULL) geom, x, y
	         			from table(sdo_util.getvertices(v_track)))
			select  t2.pp, t1.x t1x, t1.y t1y, t2.x t2x, t2.y t2y,
				    t2.geom t2geom, t1.geom t1geom,
					SDO_GEOM.SDO_DISTANCE(t2.geom, t1.geom, 1, ' UNIT=M ') rasst_points,
					sum(SDO_GEOM.SDO_DISTANCE(t2.geom, t1.geom, 1, ' UNIT=M ')) over 
					(order by t1.pp ROWS UNBOUNDED PRECEDING) rasst 		
			from t t1, t t2 
			where (t1.pp = t2.pp-1) or (t1.pp=1 and t2.pp=1)
			-- and t1.pp!=1
			order by t1.pp					 
			 ) loop	
		
	    v_x1 := k.t1x; v_x2 := k.t2x; v_y1 := k.t1y; v_y2 := k.t2y;
		
--		dbms_output.put_line(k.pp||' '||round(k.rasst_points)||' '||k.rasst||' '||v_target||' '||v_next);
		if (k.rasst >= v_target) then -- if we have passed mark
	        if (flag = 0) then      -- first mark on a part of "connector" 
				split_rate := (k.rasst-v_target)/(k.rasst_points+1);
				v_ord.EXTEND(2);
				v_ord(v_ord.LAST - 1) := split_rate*k.t1x + (1-split_rate)*k.t2x;
				v_ord(v_ord.LAST) := split_rate*k.t1y + (1-split_rate)*k.t2y;								
				flag := 1;
			end if;	

			if (k.pp != 1) then
			if (k.rasst < v_next) then  -- but don't pass next mark yet
				v_ord.EXTEND(2);
				v_ord(v_ord.LAST - 1) := k.t1x;
				v_ord(v_ord.LAST) := k.t1y;								
			else  -- сразу же перескочили через точку   			    
			    while k.rasst >= v_next loop
					v_ord.EXTEND(2);
					split_rate := (k.rasst-v_next)/(k.rasst_points+1);
					v_ord(v_ord.LAST - 1) := split_rate*k.t1x + (1-split_rate)*k.t2x;
					v_ord(v_ord.LAST) := split_rate*k.t1y + (1-split_rate)*k.t2y;						        			

					v_picket_line := SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),		
								v_ord);
				--	dbms_output.put_line('ending '||(split_rate*k.t1x + (1-split_rate)*k.t2x));
							
					insert into railid_gps_pseudo values 
					(v_railid,v_start_,v_name_txt,v_source_type,v_picket_line,
					v_direction, v_kilometeragestart + v_start_, null); 
				--	dbms_output.put_line('insert '||v_start_);
					v_ord := MDSYS.SDO_ORDINATE_ARRAY();

				-- at this point next piece starts
				--	dbms_output.put_line('begining '||(split_rate*k.t1x + (1-split_rate)*k.t2x));
					v_ord.EXTEND(2);
					split_rate := (k.rasst-v_next)/(k.rasst_points+1);
					v_ord(v_ord.LAST - 1) := split_rate*k.t1x + (1-split_rate)*k.t2x;
					v_ord(v_ord.LAST) := split_rate*k.t1y + (1-split_rate)*k.t2y;						        							

					fetch c1 into v_target, v_next,v_name_txt, v_source_type, v_start_, 
					v_direction, v_kilometeragestart;
					flag := 0;
				end loop;
			end if;
			end if;	
		end if;
	end loop;
	close c1;	
				v_ord.EXTEND(2);
				v_ord(v_ord.LAST - 1) := v_x2;
				v_ord(v_ord.LAST) := v_y2;						        			

				v_picket_line := SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),		
								v_ord);
			
				insert into railid_gps_pseudo values 
				(v_railid,v_start_,v_name_txt,v_source_type,v_picket_line,
				v_direction, v_kilometeragestart + v_start_, null); 
				flag := 0;
				v_ord := MDSYS.SDO_ORDINATE_ARRAY();				
	end loop;
	
end;


update railid_gps_pseudo a set a.j_azimuth =
(select  ROUND(COGO.Bearing(
		mdsys.sdo_point_type(fp.x, fp.y,null), 
		mdsys.sdo_point_type(lp.x, lp.y,null)) / ( 2 * Constants.pi ) * 360)
from --dual
	(select x, y from table(select sdo_util.getvertices( a.GEOM ) from dual) where id=1) fp, 
	(select x, y from table(select sdo_util.getvertices( a.GEOM ) from dual) where id=sdo_util.GETNUMVERTICES( geom )) lp
);
commit;

