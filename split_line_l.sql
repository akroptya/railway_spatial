
declare
   v_track SDO_GEOMETRY;
   v_track_before SDO_GEOMETRY;   
   v_track_after SDO_GEOMETRY;      

   v_point SDO_GEOMETRY;

   v_vertices MDSYS.VERTEX_SET_TYPE;
   v_ord MDSYS.SDO_ORDINATE_ARRAY := null;
   v_esr_start varchar2(6);  
begin
	select geom into v_point from SEPARATION_STATIONS_geom where id = 187;

select t1.geom into v_track
from SEPARATION_STATIONS_geom a1, SEPARATION_STATIONS_geom a2, kuski/*GPS_TREK*/ t1
where a1.id = 173 and a2.id = 187 and
SDO_WITHIN_DISTANCE(t1.geom, a1.geom, 'DISTANCE=200 UNIT=M')='TRUE' and
SDO_WITHIN_DISTANCE(t1.geom, a2.geom, 'DISTANCE=200 UNIT=M')='TRUE';

	split_line_l(v_track, 3365,
		v_point, 
		v_track_before,  
		v_track_after);
	
	dbms_output.put_line(v_point.SDO_POINT.x);		
	dbms_output.put_line(v_point.SDO_POINT.y);	
	dbms_output.put_line(SDO_GEOM.SDO_DISTANCE(v_point, v_track, 0.5, ' UNIT=METER '));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(v_track));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(v_track_before));
	dbms_output.put_line(SDO_UTIL.GETNUMVERTICES(v_track_after));
	
end;
