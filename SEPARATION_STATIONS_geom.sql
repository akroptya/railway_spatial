
-- Table for station coordinates

create table SEPARATION_STATIONS_geom (id number, geom SDO_GEOMETRY, source varchar2(100));
INSERT INTO USER_SDO_GEOM_METADATA VALUES
('SEPARATION_STATIONS_GEOM',  
'GEOM',SDO_DIM_ARRAY(SDO_DIM_ELEMENT('LONGITUDE',-180, 180, 0.5 ),
SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.5)),8307);
commit;
drop INDEX SEPARATION_STATIONS_geom_sidx;
CREATE INDEX SEPARATION_STATIONS_geom_sidx ON SEPARATION_STATIONS_geom(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=POINT');

insert into SEPARATION_STATIONS_geom
select a.ID, b.geom, 'name sep=hartep' 
from GAS_RAILWAY.SEPARATION_STATIONS a, GPS_ALL_STATION b
where CODE not in (select K_ESR from gps_station) and
replace(replace(replace(replace(upper(a.NAME),''',''),'''',''),' ',''),'.','') =
replace(replace(replace(replace(upper(b.NU_STAN),''',''),'''',''),' ',''),'.','')
;
commit;

insert into SEPARATION_STATIONS_geom
select -- b.NU_STAN, a.NAME
   a.ID, b.geom, 'name sep=hartep' 
from GAS_RAILWAY.SEPARATION_STATIONS a, GPS_ALL_STATION b
where id not in (select id from SEPARATION_STATIONS_geom) and
replace(replace(replace(replace(replace(replace(replace(replace(
upper(a.NAME)
,''',''),'''',''),' ',''),'.',''),'-',''),'å','º'),'è','_'),'_','î') 
=
replace(replace(replace(replace(replace(replace(replace(replace(
upper(b.NU_STAN)
,''',''),'''',''),' ',''),'.',''),'-',''),'å','º'),'è','_'),'_','î')
;
-- rollback;
commit;

insert into SEPARATION_STATIONS_geom
select a.ID, b.geom, 'code sep=hartep=klasstan'  
from GAS_RAILWAY.SEPARATION_STATIONS a, GPS_STATION b
where a.CODE = b.K_ESR;


alter table segmentrails_geom add (SOURCE varchar2(100));

declare
   v_track SDO_GEOMETRY;
   v_track_before SDO_GEOMETRY;   
   v_track_after SDO_GEOMETRY;      

   v_point SDO_GEOMETRY;

   v_vertices MDSYS.VERTEX_SET_TYPE;
   v_ord MDSYS.SDO_ORDINATE_ARRAY := null;
   v_esr_start varchar2(6);  
begin
    for k in (	/*select st1.length, k1.geom, st1.id id1, st2.id id2,
				sp1.STARTSPID STARTSPID1, sp1.FINISHSPID FINISHSPID1,
				sp2.STARTSPID STARTSPID2, sp2.FINISHSPID FINISHSPID2
		from GAS_RAILWAY.SPANS sp1, gas_railway.segmentrails st1,
		     GAS_RAILWAY.SPANS sp2, gas_railway.segmentrails st2,
			 GAS_RAILWAY.SPANS sp3, gas_railway.segmentrails st3,
	 		  kuski k1, user_sdo_geom_metadata m
		where 
		  sp1.FINISHSPID = sp2.STARTSPID and
		  sp2.FINISHSPID = sp3.STARTSPID and		  
      sp1.STARTSPID = k1.ESR_START and
	  sp2.FINISHSPID = sp3.STARTSPID and
	  sp3.FINISHSPID = k1.ESR_finish and
	  sp1.FINISHSPID not in (select id from SEPARATION_STATIONS_geom) and
	  sp2.FINISHSPID not in (select id from SEPARATION_STATIONS_geom) and	  
	  st1.segmentid = sp1.id and st1.DIRECTION in (0,1) and
	  st2.segmentid = sp2.id and st2.DIRECTION in (0,1) and
	  st3.segmentid = sp3.id and st3.DIRECTION in (0,1) 	  
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) 
	  between (st1.LENGTH+st2.LENGTH-300) and (st1.LENGTH+st2.LENGTH+300)*/	  	  
	
	select st1.length, k1.geom, st1.id id1, st2.id id2,
				sp1.STARTSPID STARTSPID1, sp1.FINISHSPID FINISHSPID1,
				sp2.STARTSPID STARTSPID2, sp2.FINISHSPID FINISHSPID2
		from GAS_RAILWAY.SPANS sp1, gas_railway.segmentrails st1,
		     GAS_RAILWAY.SPANS sp2, gas_railway.segmentrails st2,
	 		  kuski k1, user_sdo_geom_metadata m
		where sp1.FINISHSPID = sp2.STARTSPID and
      sp1.STARTSPID = k1.ESR_START and
	  sp2.FINISHSPID = k1.ESR_finish and
	  sp1.FINISHSPID not in (select id from SEPARATION_STATIONS_geom) and
	  st1.segmentid = sp1.id and st1.DIRECTION in (0,1) and
	  st2.segmentid = sp2.id and st2.DIRECTION in (0,1)
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) 
	  between (st1.LENGTH+st2.LENGTH-300) and (st1.LENGTH+st2.LENGTH+300)
	  
	  ) loop

	split_line_l(k.geom, k.length,
		v_point, 
		v_track_before,  
		v_track_after);
	
	insert into SEPARATION_STATIONS_geom (id, geom, source) 
	values (k.FINISHSPID1, v_point, 'compute Y-N-Y');
	
	insert into segmentrails_geom (id, geom, source) 
	values (k.id1, v_track_before, 'compute Y-N-Y');	

	insert into segmentrails_geom (id, geom, source) 
	values (k.id2, v_track_after, 'compute Y-N-Y');
	
	dbms_output.put_line(v_point.SDO_POINT.x);		
	dbms_output.put_line(v_point.SDO_POINT.y);	
	dbms_output.put_line(SDO_GEOM.SDO_DISTANCE(v_point, k.geom, 0.5, ' UNIT=METER '));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(k.geom));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(v_track_before));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(v_track_after));
    end loop;	  

end;


-- 85
select count(*)
from GAS_RAILWAY.SPANS sp1, GAS_RAILWAY.SPANS sp2, GAS_RAILWAY.SPANS sp3, kuski_id k
where sp1.FINISHSPID = sp2.STARTSPID and
	  sp2.FINISHSPID = sp3.STARTSPID and
      sp1.STARTSPID = k.id_start and
	  sp3.FINISHSPID = k.id_finish and
	  (sp1.FINISHSPID not in (select id from SEPARATION_STATIONS_geom)
	  or
	  sp2.FINISHSPID not in (select id from SEPARATION_STATIONS_geom)
	  );

-- 106
select count(*)
from GAS_RAILWAY.SPANS sp1, GAS_RAILWAY.SPANS sp2, GAS_RAILWAY.SPANS sp3, 
	 GAS_RAILWAY.SPANS sp4, kuski_id k
where sp1.FINISHSPID = sp2.STARTSPID and
	  sp2.FINISHSPID = sp3.STARTSPID and
	  sp2.FINISHSPID = sp4.STARTSPID and	  
      sp1.STARTSPID = k.id_start and
	  sp4.FINISHSPID = k.id_finish and
	  (sp1.FINISHSPID not in (select id from SEPARATION_STATIONS_geom)
	  or
	  sp2.FINISHSPID not in (select id from SEPARATION_STATIONS_geom)
	  or
	  sp3.FINISHSPID not in (select id from SEPARATION_STATIONS_geom)	  
	  );	  


