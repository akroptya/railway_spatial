function       f_split_line_l (p_track SDO_GEOMETRY, length_ number) return sdo_geometry 
is 
res_point SDO_GEOMETRY;
res_track_before SDO_GEOMETRY;
res_track_after SDO_GEOMETRY;
begin 
TELEM.SPLIT_LINE_L(p_track, length_, res_point, res_track_before, res_track_after);
return res_point;
end;