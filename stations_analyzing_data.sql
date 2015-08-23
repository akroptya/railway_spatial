
--- Verifying Data Clearance

-- guessing about distance between stopping vehicle and center of station 
select b.imei
from gps_station a, real_tracks b
where K_ESR = '440406' and 
SDO_WITHIN_DISTANCE(b.geom, a.geom, 'DISTANCE=200 UNIT=M')='TRUE'
;


--  396 abscent in dictionary table
select count(*) from GAS_RAILWAY.SEPARATION_STATIONS
where CODE not in (select K_ESR from klasstan@uzc1)
;

-- 815 do not have coordinates in source data, 396 colud not have as the are not from dictionary
select count(*) from GAS_RAILWAY.SEPARATION_STATIONS
where CODE not in (select K_ESR from gps_station)
;

select * from GAS_RAILWAY.SEPARATION_STATIONS
where id not in (select id from SEPARATION_STATIONS_geom)
and NAME not like '%Б/П%' 
and NAME not like '%Пост%' 
and NAME not like '%Стр.%' 
and NAME not like '%ТУ%' 
and NAME not like '%Держкордон%' 
and NAME not like '%Рзд.%' 
and NAME not like '%РЖД%' 
and NAME not like '%Межа з%' 
order by length(code) desc, code
;

-- stations abscent from dictionary but names are known 
select * from GAS_RAILWAY.SEPARATION_STATIONS
where CODE not in (select K_ESR from gps_station) and
upper(NAME) in (select upper(NU_STAN) from GPS_ALL_STATION)
;


-- 181 are not from dictionary but are on a track between two known stations from dictionary
select count(distinct sp1.FINISHSPID) 
from GAS_RAILWAY.SPANS sp1, GAS_RAILWAY.SPANS sp2
where
sp2.STARTSPID = sp1.FINISHSPID and
sp1.FINISHSPID in (select id from GAS_RAILWAY.SEPARATION_STATIONS
where CODE not in (select K_ESR from klasstan@uzc1)) 
and sp1.STARTSPID in (select id from GAS_RAILWAY.SEPARATION_STATIONS
where CODE in (select K_ESR from klasstan@uzc1))
and sp2.FINISHSPID in (select id from GAS_RAILWAY.SEPARATION_STATIONS
where CODE in (select K_ESR from klasstan@uzc1))
;

-- two neighbour stations with known coordinates and railway link but track data is abscent 
-- 439
select *
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp
where st.DIRECTION in (0,1) and st.LNO = 1 and st.segmentid = sp.id
	  and SP.STARTSPID in (select id from SEPARATION_STATIONS_geom)
	  and SP.FINISHSPID in (select id from SEPARATION_STATIONS_geom)
	  and st.id not in (select id from segmentrails_geom);

-- links with know coordinates of first and second stations
-- 1453
select *
from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp
where st.DIRECTION in (0,1) and st.LNO = 1 and st.segmentid = sp.id
	  and SP.STARTSPID in (select id from SEPARATION_STATIONS_geom)
	  and SP.FINISHSPID in (select id from SEPARATION_STATIONS_geom);



