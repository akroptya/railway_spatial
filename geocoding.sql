
-- 1. get xmls from google by station names to local table
-- 2. parse xml's and get stations coordinates 
-- 3. verify obtained coordinates 
-- &bounds=34.172684,-118.604794|34.236144,-118.500938
-- http://maps.googleapis.com/maps/api/geocode/xml?address=станция+ПЕРЕСЕЧНАЯ&sensor=false
SELECT * FROM   klasstan;
 SELECT * FROM   sys.APPLY$_S2@uzc1;
delete from geocodes;
alter table geocodes add (K_ESR CHAR(6));

select * from geocodes;

create table klasstan_s2 as
select *
from arm_spr.klasstan@uzc1
where K_ADM = '22' and k_esr not in (select K_ESR from sys.APPLY$_S2@uzc1);

select *  from klasstan_s2;

create table geocodes (geocode_answer CLOB, geocode_ask varchar2(1000), web_source varchar2(32));

declare
   v_geocode_answer CLOB;
   v_geocode_ask varchar2(1000);
   v_google_addr varchar2(1000) := 'http://maps.googleapis.com/maps/api/geocode/xml?address=станция+';
begin
    DBMS_LOB.CREATETEMPORARY(v_geocode_answer, TRUE);
    for k in (select N_STAN, K_ESR from klasstan_s2) loop
        v_geocode_ask := v_google_addr||k.N_STAN||'&sensor=false';
        v_geocode_answer := mygetclobFromUrl(v_geocode_ask);
        insert into geocodes values (v_geocode_answer, v_geocode_ask, 'google', k.k_esr);
        commit;
        dbms_lock.sleep(3);
    end loop;
    DBMS_LOB.freeTEMPORARY(v_geocode_answer);
end;    
