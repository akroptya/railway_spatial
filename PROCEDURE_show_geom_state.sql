rchar2 default '12896004335318',
p_dat1 varchar2 default to_char(trunc(sysdate),'dd.mm.yyyyhh24:mi:ss'),
p_dat2 varchar2 default to_char(sysdate,'dd.mm.yyyyhh24:mi:ss')) is
 v_count number;
 v_imei varchar2(100) := '12896004335318';
 v_START_ number;
 v_id number;
 v_dat1 date;
 v_dat2 date;
 v_ts date := to_Date('01.01.2000','dd.mm.yyyy');
 v_len number;
begin
	v_imei := p_imei;
	v_dat1 := to_date(p_dat1,'dd.mm.yyyyhh24:mi:ss');
	v_dat2 := to_date(p_dat2,'dd.mm.yyyyhh24:mi:ss');

	htp.p('<html><body>');
/*	select count(*) into v_count
	from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp
	where st.DIRECTION in (0,1) and st.LNO = 1 and st.segmentid = sp.id;
	htp.p('Всего сегментов: '||v_count);

	select count(*) into v_count
	from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp
	where
	st.DIRECTION in (0,1) and st.LNO = 1 and st.segmentid = sp.id
	and SP.STARTSPID in (select distinct id from SEPARATION_STATIONS_geom where SOURCE != 'compute Y-N-Y')
    and SP.FINISHSPID in (select distinct id from SEPARATION_STATIONS_geom where SOURCE != 'compute Y-N-Y');
	htp.p('<br/> Cегментов для которых известны координаты начала и конца: '||v_count);

	select count(*) into v_count
	from gas_railway.segmentrails st, GAS_RAILWAY.SPANS sp
	where
	st.DIRECTION in (0,1) and st.LNO = 1 and st.segmentid = sp.id
	and
	(SP.STARTSPID in (select distinct id from SEPARATION_STATIONS_geom where SOURCE != 'compute Y-N-Y')
    or SP.FINISHSPID in (select distinct id from SEPARATION_STATIONS_geom where SOURCE != 'compute Y-N-Y'))
	;
	htp.p('<br/> Cегментов для которых известны координаты начала или конца: '||v_count);

	select count(*) into v_count
	from segmentrails_geom;
	htp.p('<br/> Cегментов с треками: '||v_count);*/

   for k in (select
				ROAD.N_DORU DOR,
				ROAD.KD,
				DEPO.NAME_PIDPR DEPO,
				DEPO.DEPO KDEPO,
				SER.NAME SER,
				LOK.NAME_LOK LOK,
				LNODE.NOM NOM_UZEL,
				LNODE.KOD_IMEI IMEI,
				STAN_LOK.MNK_GR_2 STATE_LOK
			from
				md_lnode.srez_actual_lnode@dl_vpeo lnode,
				md_sec.srez_actual_sec@dl_vpeo sec,
				md_lok.srez_actual_tps@dl_vpeo lok,
				nsi.v_dic_depo@dl_vpeo depo,
				nsi.v_dic_ser@dl_vpeo ser,
				psvnsi.d_zalsnd@dl_vpeo road,
				nsi_prog.VW_GROUP_STAN_TRS@dl_vpeo stan_lok
			where
				LNODE.KOD_IMEI = 12896004407513 and
				LNODE.OZN_TYPE =10 and
				LNODE.KOD_OBJ_DISL = SEC.IDF_SEC(+) and
				SEC.KOD_OBJ_DISL = LOK.IDF_TPS(+) and
				LNODE.ID_DEPO = DEPO.ID_DEPO(+) and
				SEC.ID_SER = SER.ID_SER(+) and
				DEPO.DOR = road.KD(+) and
				lok.st_code_work = STAN_LOK.KOD_STAN(+)
			order by DOR, DEPO, SER, LOK asc) loop
	htp.p('<center><H2> Рух локомотива з imei: '||v_imei||' </br>
	в географ?чних та зал?зничних координатах <br />
	    з '||to_char(v_dat1,'dd.mm.yyyy hh24:mi:ss')||' по '||to_char(v_dat2,'dd.mm.yyyy hh24:mi:ss')||'</H2> </center>');

	htp.p('дорога локомотива: '||k.DOR||' ('||k.KD||') </br>
	депо: '||k.DEPO||' ('||k.KDEPO||') </br>
	сер?я: '||k.SER||' </br>
	номер: '||k.LOK||' </br>
	вузол: '||k.NOM_UZEL||' </br>
	стан: '||k.STATE_LOK||' </br></br>');

end loop;


	htp.p('<table>');
	htp.p('<tr style="border: thin solid black; text-align: center; font-weight: bold;">
	<td>час</td><td>об''єкт</td><td>тип</td><td>швидк.</td><td>п?кет</td><td>коорд.</td><td>сегмент</td><td>N</td><td>E</td>
	</tr>');



	for k in (
	select b.ts, rd.dist, rd.NAME_TXT, rd.SOURCE_TYPE, rd.START_, id, rd.right_direct,
		   b.SPEED, rd.geom, b.geom_p, rd.KOORDM,
		   (case when rd.direction = 2 then -1 else 1 end)*LENGTH_FROM_START(rd.geom, rd.geom_p) len
    from (select TMS.TIMESTAMP ts,
						mdsys.sdo_geometry(2001,8307,mdsys.sdo_point_type(LON/10000000,LAT/10000000,null),null,null) geom_p,
						TMS.SPEED,
						lag(SPEED,1,1) over (order by TIMESTAMP) prev_SPEED
				from TELEM.TRACKER_DATA@dl_vpnsi tms
				where
					tms.imei = v_imei
					and TMS.PART between to_char(v_dat1,'dd') and to_char(v_dat2,'dd')
					and TMS.TIMESTAMP between v_dat1 and v_dat2
					--and SPEED != 0
					) b
	left outer join
	(select * from (select 	ts, dist, NAME_TXT, SOURCE_TYPE, START_, id, right_direct,
			SPEED, geom, geom_p, KOORDM, direction,
			lag(id,1,null) over (partition by id order by ts) prev_id,
			lag(START_,1,null) over (partition by id order by ts) prev_START_,
			RANK() OVER (PARTITION BY ts ORDER BY count_id desc) rnk
	from
	(select 	ts, dist, NAME_TXT, SOURCE_TYPE, START_, id, right_direct,
			SPEED, geom, geom_p, KOORDM, direction,
			count(*) over (PARTITION BY ID ORDER BY ts ROWS 50 PRECEDING) count_id
	from
		(select st1.ts, dist, NAME_TXT, SOURCE_TYPE, START_, SPEED, geom, geom_p, KOORDM,
				st1.id, direction,
				(case when direction = 2 then -1 else 1 end) *(SUM (START_-START_lag)
        		  OVER (PARTITION BY ID ORDER BY TS ROWS BETWEEN 10 PRECEDING AND 10 FOLLOWING)
				) right_direct
		from
			(select b.RAILID id, a.ts, NAME_TXT, SOURCE_TYPE, START_,
					b.geom, a.geom_p, b.KOORDM,
					SDO_GEOM.SDO_DISTANCE(b.geom, a.geom_p, 0.5, ' UNIT=METER ') dist,
					lag(START_,1,START_) over (partition by b.RAILID order by ts) START_lag,
					b.direction,
					SPEED
			from (select TMS.TIMESTAMP ts,
						mdsys.sdo_geometry(2001,8307,mdsys.sdo_point_type(LON/10000000,LAT/10000000,null),null,null) geom_p,
						TMS.SPEED
				from TELEM.TRACKER_DATA@dl_vpnsi tms
				where
					tms.imei = v_imei
					and TMS.PART between to_char(v_dat1,'dd') and to_char(v_dat2,'dd')
					and TMS.TIMESTAMP between v_dat1 and v_dat2
					and SPEED != 0
					) a left outer join railid_gps_pseudo b
											on
								-- SDO_WITHIN_DISTANCE(b.geom, a.geom_p, 'DISTANCE=400 UNIT=M')='TRUE'
							  	SDO_NN(b.geom, a.geom_p, 'SDO_NUM_RES=2 DISTANCE=400',1)='TRUE'
				) st1) where right_direct >= 0)) where rnk = 1  ) rd
				   on
				   	b.ts = rd.ts
				left outer join RAIL_pseudo_JOINTS pj
				   on
					pj.railid = rd.id and
					pj.railid = rd.prev_id and
					((rd.direction != 2 and pj.start_ > rd.prev_START_ and pj.start_ <= rd.START_)
					or
					(rd.direction = 2 and pj.start_ < rd.prev_START_ and pj.start_ >= rd.START_))
	where not(b.SPEED = 0 and b.prev_SPEED = 0)
	order by b.ts) loop

--	if k.ts != v_ts then
--	if k.id is not null then
/*	select k.KOORDM + LENGTH_FROM_START(st.geom, k.geom) into v_len from railid_gps_pseudo st
	where st.railid = k.id and start_ = k.START_ and rownum < 2;*/
--		if k.right_direct >= 0 then
	if v_START_ != k.START_ or v_id != k.id then
	if (k.ts-v_ts) > 20/(1440*60) and (k.ts-v_ts) < 1 then
		htp.p('<tr><td>'||to_char(k.ts,'hh24:mi:ss dd.mm')||' зупинка '||round((k.ts-v_ts)*(1440*60))||'с</td>');
	else
		htp.p('<tr><td>'||to_char(k.ts,'hh24:mi:ss dd.mm')||'</td>');
	end if;
	htp.p('<td>'||case when(v_START_ != k.START_ or v_id != k.id) then k.NAME_TXT else '&nbsp' end||'</td>');
	htp.p('<td>'||case when(v_START_ != k.START_ or v_id != k.id) then k.SOURCE_TYPE else '&nbsp' end||'</td>');
	htp.p('<td>'||k.SPEED||'</td>');
	htp.p('<td align="right">'||to_char((k.KOORDM+k.len)/1000,'9990.999')||'</td>');
--	htp.p('<td align="right">'||round(k.len)||'</td>');
--	htp.p('<td align="right">'||round(k.START_)||'</td>');
	htp.p('<td align="right">'||case when(v_START_ != k.START_ or v_id != k.id) then to_Char(k.START_) else '&nbsp' end||'</td>');
	htp.p('<td>'||case when(v_START_ != k.START_ or v_id != k.id) then to_Char(k.id) else '&nbsp' end||'</td>');
		htp.p('<td>'||to_char(k.geom_p.SDO_POINT.y,'99.9999999')||'</td>');
		htp.p('<td>'||to_char(k.geom_p.SDO_POINT.x,'99.9999999')||'</td>');
		htp.p('</tr>');
	else
		if (k.ts-v_ts) > 20/(1440*60) and (k.ts-v_ts) < 1 then
			htp.p('<tr style="background-color: #E5E4E2"><td>'||to_char(k.ts,'hh24:mi:ss dd.mm')||' зупинка '||round((k.ts-v_ts)*(1440*60))||'с</td>');
		else
				htp.p('<tr style="background-color: #E5E4E2"><td>'||to_char(k.ts,'hh24:mi:ss dd.mm')||'</td>');
		end if;
		htp.p('<td>&nbsp</td>');
		htp.p('<td>&nbsp</td>');
    	htp.p('<td>'||k.SPEED||'</td>');
    	htp.p('<td align="right">'||to_char((k.KOORDM+k.len)/1000,'9990.999')||'</td>');
--    	htp.p('<td align="right">'||round(k.len)||'</td>');
		htp.p('<td>&nbsp</td>');
--    	htp.p('<td align="right">'||round(k.START_)||'</td>');
		htp.p('<td>'||k.id||'</td>');
		htp.p('<td>'||to_char(k.geom_p.SDO_POINT.y,'99.9999999')||'</td>');
		htp.p('<td>'||to_char(k.geom_p.SDO_POINT.x,'99.9999999')||'</td>');
		htp.p('</tr>');
	end if;
--		end if;
/*	else
	htp.p('<td>'||'--------------------------------'||'</td>');
	end if;*/
	v_START_ := k.START_;
	v_id := k.id;
	v_ts := k.ts;
--	end if;
	end loop;
	htp.p('</table>');
/*
	select
	TMS.IMEI,
	TMS.TIMESTAMP,
	TMS.LAT/10000000 LAT,
	TMS.LON/10000000 LON,
	TMS.ANGLE/100 ANGLE,
TMS.SPEED,
TMS.DATE_END,
TMS.ALTITUDE,
TMS.GSM_SIGNAL,
TMS.HDOP,
TMS.SATELITES,
TMS.VOLTAGE
from TELEM.TRACKER_DATA tms
where
TMS.PART between to_char(:d_beg,'dd') and to_char(:d_end,'dd')
and TMS.IMEI = :imei
and TMS.TIMESTAMP between :d_beg and :d_end */


	htp.p('</body></html>');
end;
