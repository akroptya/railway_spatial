PROCEDURE split_line_l (p_track in mdsys.SDO_GEOMETRY, p_from_start number,
p_point out mdsys.SDO_GEOMETRY, p_track_before out mdsys.SDO_GEOMETRY,
p_track_after out mdsys.SDO_GEOMETRY)
        is
   	v_ord MDSYS.SDO_ORDINATE_ARRAY := null;
	split_rate number;
	v_found number := 0;
begin
	v_ord := MDSYS.SDO_ORDINATE_ARRAY();
	for k in (select id, x, y, lag_x, lag_y, rasst_points,
	sum(rasst_points) over (order by id ROWS UNBOUNDED PRECEDING) rasst
	 from ( select id, x, y, lag_x, lag_y,
	   		SDO_GEOM.SDO_DISTANCE(
			SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(x,y,NULL),NULL,NULL),
			SDO_GEOMETRY(2001,8307, SDO_POINT_TYPE(lag_x,lag_y,NULL),NULL,NULL),
			0.5, ' UNIT=M ') rasst_points
	   from(select id, x, y,
					lag(x,1,x) over (order by id) lag_x,
					lag(y,1,y) over (order by id) lag_y
	   from TABLE(SDO_UTIL.GETVERTICES(p_track)))) order by id) loop

	   if (k.rasst >= p_from_start and v_found = 0) then
			v_found := 1;
			split_rate := (k.rasst-p_from_start)/k.rasst_points;

			p_point := SDO_GEOMETRY(2001,8307,
				SDO_POINT_TYPE(split_rate*k.lag_x + (1-split_rate)*k.x,
							   split_rate*k.lag_y + (1-split_rate)*k.y,NULL),NULL,NULL);

	   	   	v_ord.EXTEND(2);
			v_ord(v_ord.LAST - 1) := p_point.SDO_POINT.x;
	   	   	v_ord(v_ord.LAST) := p_point.SDO_POINT.y;
			p_track_before := SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),v_ord);

			v_ord := MDSYS.SDO_ORDINATE_ARRAY();
	   	   	v_ord.EXTEND(2);
		   	v_ord(v_ord.LAST - 1) := p_point.SDO_POINT.x;
	   	   	v_ord(v_ord.LAST) := p_point.SDO_POINT.y;
	   end if;
	   v_ord.EXTEND(2);
	   v_ord(v_ord.LAST - 1) := k.x;
	   v_ord(v_ord.LAST) := k.y;
	end loop;
	p_track_after := SDO_GEOMETRY(2002,8307,NULL,SDO_ELEM_INFO_ARRAY (1,2,1),v_ord);
end;
