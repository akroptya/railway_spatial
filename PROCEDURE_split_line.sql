PROCEDURE split_line (p_track in SDO_GEOMETRY, p_point in SDO_GEOMETRY, p_track_before out SDO_GEOMETRY,  p_track_after out SDO_GEOMETRY)
        is
   v_ord MDSYS.SDO_ORDINATE_ARRAY := null;
begin
	v_ord := MDSYS.SDO_ORDINATE_ARRAY();
	for k in (
	   select id, x, y, dist, min(dist) over () mindist
	   from (select id, x, y,
		SDO_GEOM.SDO_DISTANCE(SDO_GEOMETRY(2001,8307,SDO_POINT_TYPE(x, y, null),null,null),
							  p_point, 0.5, ' UNIT=METER ') dist
		     from TABLE(SDO_UTIL.GETVERTICES(p_track))) tr
	   order by id) loop

	   if (k.dist = k.mindist) then
	   	   	v_ord.EXTEND(2);
		   	v_ord(v_ord.LAST - 1) := p_point.SDO_POINT.x;
	   	   	v_ord(v_ord.LAST) := p_point.SDO_POINT.y;
			p_track_before := SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),v_ord);
			v_ord := MDSYS.SDO_ORDINATE_ARRAY();
	   	   	v_ord.EXTEND(2);
		   	v_ord(v_ord.LAST - 1) := p_point.SDO_POINT.x;
	   	   	v_ord(v_ord.LAST) := p_point.SDO_POINT.y;
	   else
	   		v_ord.EXTEND(2);
			v_ord(v_ord.LAST - 1) := k.x;
			v_ord(v_ord.LAST) := k.y;
	   end if;
	end loop;
	p_track_after := SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),v_ord);
end;
