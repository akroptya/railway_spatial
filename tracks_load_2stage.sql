
-- load second stage tracks
CREATE OR REPLACE 
type lon_lat as array(2) of number;

CREATE OR REPLACE 
type lineordinatesimpl as object
(
  p_ordinates MDSYS.SDO_ELEM_INFO_ARRAY, -- array of coordinates to de filled 
  static function ODCIAggregateInitialize(sctx IN OUT LineOrdinatesImpl) return number,
  member function ODCIAggregateIterate(self IN OUT LineOrdinatesImpl, 
                                       p_lon_lat IN lon_lat) return number,
  member function ODCIAggregateTerminate(self IN LineOrdinatesImpl, 
                                returnValue OUT MDSYS.SDO_ELEM_INFO_ARRAY, flags IN number) return number,
  member function ODCIAggregateMerge(self IN OUT LineOrdinatesImpl, 
                                ctx2 IN LineOrdinatesImpl) return number
);

create or replace FUNCTION LineOrdinates (p_lon_lat lon_lat) RETURN SDO_ELEM_INFO_ARRAY 
PARALLEL_ENABLE AGGREGATE USING LineOrdinatesImpl;

CREATE OR REPLACE 
TYPE BODY lineordinatesimpl is

static function ODCIAggregateInitialize(sctx IN OUT LineOrdinatesImpl) return number is
begin
  sctx := LineOrdinatesImpl(MDSYS.SDO_ELEM_INFO_ARRAY());
  return ODCIConst.Success;
end;

  member function ODCIAggregateIterate(self IN OUT LineOrdinatesImpl,
                                       p_lon_lat IN lon_lat) return number
is
begin
    self.p_ordinates.EXTEND(2);
    self.p_ordinates(self.p_ordinates.COUNT()-1) := p_lon_lat(1);
    self.p_ordinates(self.p_ordinates.COUNT()) := p_lon_lat(2);
    return ODCIConst.Success;
end;

member function ODCIAggregateTerminate(self IN LineOrdinatesImpl,
                                returnValue OUT MDSYS.SDO_ELEM_INFO_ARRAY, flags IN number) return number is
begin
  returnValue := self.p_ordinates;
  return ODCIConst.Success;
end;

  member function ODCIAggregateMerge(self IN OUT LineOrdinatesImpl,
                                ctx2 IN LineOrdinatesImpl) return number is
 begin
 -- self.p_ordinates := ctx2.p_ordinates;
 null;
  return ODCIConst.Success;
end;

end;



insert into GPS_TREK 
select  HEADER, 
        SDO_GEOMETRY(
            2002, -- SDO_GTYPE: D00T. Set to 2002 as it is a 2-dimensional line string
            8307, -- SDO_SRID (geodetic)
            NULL, -- SDO_POINT_TYPE is null
            SDO_ELEM_INFO_ARRAY 
            (1, -- Offset is 1
            2, -- Element-type is 2 for a LINE STRING
            1 -- Interpretation is 1 if line string is connected by straight lines.
            ),
            cast(ordinates as SDO_ORDINATE_ARRAY)) geom
from
(select pp,max_pp, HEADER, 
    LineOrdinates(lon_lat(lon, lat)) over (partition by HEADER order by pp)  ordinates
from (select header, round(floor(lon/100.0)+((lon-floor(lon/100.0)*100)/60.0),6) lon, 
                     round(floor(lat/100.0)+((lat-floor(lat/100.0)*100)/60.0),6) lat,
                     pp, max(pp) over (partition by header) max_pp
from RAW_GPS_TREK_DATA
order by HEADER, PP))
where pp = max_pp;
commit;

update gps_trek set geom = SDO_UTIL.REMOVE_DUPLICATE_VERTICES(geom,0.01);
commit;

SELECT distinct header, SDO_GEOM.VALIDATE_GEOMETRY_WITH_CONTEXT(geom, 0.01)
from gps_trek;
