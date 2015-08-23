function length_from_start(p_track in SDO_GEOMETRY, p_point in SDO_GEOMETRY) return number 
deterministic
is 
v_track_before SDO_GEOMETRY;  
v_track_after SDO_GEOMETRY;
begin
	split_line(p_track, p_point, v_track_before, v_track_after);
	return sdo_geom.sdo_length(v_track_before,1,'unit=meter');
end;
