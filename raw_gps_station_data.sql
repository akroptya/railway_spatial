CREATE TABLE raw_gps_station_data
    (full_name                      VARCHAR2(3000 BYTE),
    header                         VARCHAR2(1000 BYTE),
    pp                             NUMBER,
    kod                            VARCHAR2(200 BYTE),
    lon                            NUMBER,
    lat                            NUMBER,
    height                         VARCHAR2(5 BYTE),
    name                           VARCHAR2(1000 BYTE),
    koordinata                     NUMBER,
    nmea                           VARCHAR2(1000 BYTE));

drop table raw_gps_data;
CREATE TABLE raw_gps_track_data
    (full_name                      VARCHAR2(3000 BYTE),
    header                         VARCHAR2(1000 BYTE),
    pp                             NUMBER,
    kod                            VARCHAR2(200 BYTE),
    lon                            NUMBER,
    lat                            NUMBER,
    height                         VARCHAR2(5 BYTE),
    name                           VARCHAR2(1000 BYTE),
    nmea                           VARCHAR2(1000 BYTE),
    pero                           VARCHAR2(5 BYTE));  
    
    CREATE TABLE raw_gps_stoppoint_data
    (full_name                      VARCHAR2(3000 BYTE),
    header                         VARCHAR2(1000 BYTE),
    pp                             NUMBER,
    kod                            VARCHAR2(200 BYTE),
    lon                            NUMBER,
    lat                            NUMBER,
    height                         VARCHAR2(5 BYTE),
    name                           VARCHAR2(1000 BYTE),
    koordinata                     VARCHAR2(30 BYTE),
    nmea                           VARCHAR2(1000 BYTE));
      
