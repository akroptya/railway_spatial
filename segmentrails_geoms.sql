create table segmentrails_geom (id number, geom SDO_GEOMETRY);
INSERT INTO USER_SDO_GEOM_METADATA VALUES
('SEGMENTRAILS_GEOM',  -- имя таблицы
'GEOM',SDO_DIM_ARRAY(SDO_DIM_ELEMENT('LONGITUDE',-180, 180, 0.5 ),
SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.5)),8307);
commit;
CREATE INDEX segmentrails_geom_sidx ON segmentrails_geom(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=LINE');


select k1.id, k1.ESR_START, k1.ESR_FINISH, SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo), st.LENGTH
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp,
	 GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2,
	 kuski k1, user_sdo_geom_metadata m 
where 
      st.segmentid = sp.id
	  and SP.STARTSPID = ss1.id and SP.FINISHSPID = ss2.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and k1.ESR_START = ss1.id and k1.ESR_FINISH = ss2.id and 
 	  SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) between (st.LENGTH-400) and (st.LENGTH+400)
; 

create table kuski2 as select * from kuski;
truncate table kuski2;
alter table kuski2 add (fLENGTH number);
alter table kuski2 drop primary key;
alter table kuski2 add primary key (ESR_START, ESR_FINISH);

begin
	for k in (select k1.id, k1.ESR_START, k1.ESR_FINISH,  k1.geom,
	SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo), st.LENGTH
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp,
	 GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2,
	 kuski k1, user_sdo_geom_metadata m 
where 
      st.segmentid = sp.id
	  and SP.STARTSPID = ss1.id and SP.FINISHSPID = ss2.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and k1.ESR_START = ss1.id and k1.ESR_FINISH = ss2.id and 
 	  SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) between (st.LENGTH-400) and (st.LENGTH+400)
order by k1.ESR_START, k1.ESR_FINISH, abs(SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo)-st.LENGTH)
) loop
	begin
		insert into kuski2 values 
		(k.ID, k.ESR_START, k.ESR_FINISH, k.GEOM, k.LENGTH);
		exception when others then null;
	end;
end loop;

	for k in (select k1.id, k1.ESR_START, k1.ESR_FINISH,  k1.geom,
	SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo), st.LENGTH
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp,
	 GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2,
	 kuski k1, user_sdo_geom_metadata m 
where 
      st.segmentid = sp.id
	  and SP.STARTSPID = ss1.id and SP.FINISHSPID = ss2.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and k1.ESR_FINISH = ss1.id and k1.ESR_START = ss2.id and 
 	  SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) between (st.LENGTH-400) and (st.LENGTH+400)
order by k1.ESR_START, k1.ESR_FINISH, abs(SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo)-st.LENGTH)
) loop
	begin
		insert into kuski2 values 
		(k.ID, k.ESR_START, k.ESR_FINISH, k.GEOM, k.LENGTH);
		exception when others then null;
	end;	
end loop;
end;

delete kuski;
insert into kuski select k.ID, k.ESR_START, k.ESR_FINISH, k.GEOM from kuski2 k;
commit;


select ESR_START, ESR_FINISH, count(*) from kuski2
group by ESR_START, ESR_FINISH
having count(*)> 1;

insert into segmentrails_geom
select st.id, k1.geom, null
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp,
	 GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2,
	 kuski2 k1, user_sdo_geom_metadata m 
where -- st.DIRECTION in (0,1) and st.LNO = 1 and 
      st.segmentid = sp.id
	  and SP.STARTSPID = ss1.id and SP.FINISHSPID = ss2.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and k1.ESR_START = ss1.id and k1.ESR_FINISH = ss2.id and 
	 -- fLENGTH = st.LENGTH
 	  SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) between (st.LENGTH-400) and (st.LENGTH+400)
;
insert into segmentrails_geom
select st.id, SDO_UTIL.REVERSE_LINESTRING(k1.geom) , null
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp,
	 GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2,
	 kuski2 k1, user_sdo_geom_metadata m 
where -- st.DIRECTION in (0,1) and st.LNO = 1 and 
      st.segmentid = sp.id
	  and SP.STARTSPID = ss1.id and SP.FINISHSPID = ss2.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and k1.ESR_FINISH = ss1.id and k1.ESR_START = ss2.id and 
-- 	  fLENGTH = st.LENGTH and
	  st.id not in (select id from segmentrails_geom) and
	   SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) between (st.LENGTH-400) and (st.LENGTH+400)
;
commit;

select * from GPS_TREK A join SEPARATION_STATIONS_geom ss1 on
				SDO_GEOM.SDO_DISTANCE(a.geom, ss1.geom, 0.5, ' UNIT=METER ') < 400
				 join SEPARATION_STATIONS_geom ss2 on 
				SDO_GEOM.SDO_DISTANCE(a.geom, ss2.geom, 0.5, ' UNIT=METER ') < 400
where ss1.id = 10170 and ss2.id = 10172;

select st.id, k1.geom, null
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp,
	 GAS_RAILWAY.SEPARATION_STATIONS ss1, GAS_RAILWAY.SEPARATION_STATIONS ss2,
	 kuski k1, user_sdo_geom_metadata m 
where -- st.DIRECTION in (0,1) and st.LNO = 1 and 
      st.segmentid = sp.id
	  and SP.STARTSPID = ss1.id and SP.FINISHSPID = ss2.id
	  and m.table_name = 'KUSKI' AND m.column_name = 'GEOM'
	  and k1.ESR_START = ss1.id and k1.ESR_FINISH = ss2.id and 
 	  SDO_GEOM.SDO_LENGTH(k1.geom, m.diminfo) between (st.LENGTH-200) and (st.LENGTH+200) and 
	  k1.ESR_START = 10170 and k1.ESR_FINISH = 10172
;

select st.id, st.LENGTH
from gas_railway.segmentrails st
where st.DIRECTION in (0,1) and st.LNO = 1
and st.id not in (select id from segmentrails_geom)
order by st.id;

create table real_tracks as
select IMEI, SDO_GEOMETRY(
            2002, -- SDO_GTYPE: D00T. Set to 2002 as it is a 2-dimensional line string
            8307, -- SDO_SRID (geodetic)
            NULL, -- SDO_POINT_TYPE is null
            SDO_ELEM_INFO_ARRAY 
            (1, -- Offset is 1
            2, -- Element-type is 2 for a LINE STRING
            1 -- Interpretation is 1 if line string is connected by straight lines.
            ),
            cast(ord as SDO_ORDINATE_ARRAY)) geom,
			to_date('20.02.2014','dd.mm.yyyy') DATE_OP_SSN   from 
(select IMEI,maxdat, DATE_OP_SSN, 
case when DATE_OP_SSN = maxdat then
LineOrdinates(lon_lat(lon/10000000, LAT/10000000)) over (partition by IMEI order by DATE_OP_SSN)
else null end ord
from
(select IMEI, DATE_OP_SSN, LAT,  LON, 
max(DATE_OP_SSN) over (partition by IMEI) maxdat 
from tracker_data 
where 
	DATE_OP_SSN > to_date('20.02.2014','dd.mm.yyyy') and 
	DATE_OP_SSN < to_date('21.02.2014','dd.mm.yyyy') and
	SPEED != 0 
	-- and IMEI = 12896004361850
	))
where DATE_OP_SSN = maxdat	
;

INSERT INTO USER_SDO_GEOM_METADATA VALUES
('REAL_TRACKS',  
'GEOM',SDO_DIM_ARRAY(SDO_DIM_ELEMENT('LONGITUDE',-180, 180, 0.5 ),
SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.5)),8307);
commit;
drop INDEX real_tracks_sidx;
CREATE INDEX real_tracks_sidx ON real_tracks(geom) INDEXTYPE IS MDSYS.SPATIAL_INDEX
PARAMETERS ('LAYER_GTYPE=LINE');


