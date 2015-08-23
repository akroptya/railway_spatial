function       get_first_point (geom sdo_geometry) return sdo_geometry 
is 
begin 
return 
sdo_geometry (2001, geom.sdo_srid, 
sdo_point_type (geom.sdo_ordinates(1), geom.sdo_ordinates(2), null), null, null); 
end;