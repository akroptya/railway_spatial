begin
dbms_output.put_line('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title>Перегоны</title>
    <meta http-equiv="Content-Type" content="text/html;
 
charset=windows-1251"/>
 
    <!--
        Подключаем API карт 2.x
        Параметры:
          - load=package.full - полная сборка;
          - lang=ru-RU - язык русский.
    -->
    <script
 
src="http://api-maps.yandex.ru/2.0/?load=package.full&lang=ru-RU"
            type="text/javascript"></script>
 
    <script type="text/javascript">
        // Как только будет загружен API и готов DOM, выполняем инициализацию
        ymaps.ready(init);
 
        function init () {
            var myMap = new ymaps.Map("map", {
                    center: [48, 30],
                    zoom: 6
                });
');
    for k in (select rownum pp, geom from
    (select geom  from test2 where 
    k_esr1 != k_esr2 and header like ('%Київ%')
    order by id1)) loop
    dbms_output.put_line('
    var myPolyline'||k.pp||' = new ymaps.GeoObject({
    geometry: {
        type: "LineString",
        coordinates: [');        

        for n in (select listagg('['||to_char(y,'99.99999')||', '||to_char(x,'99.99999')||']',', ') WITHIN GROUP (order by id) koord
                 from TABLE(SDO_UTIL.GETVERTICES(k.geom)))  loop
            null;   
            dbms_output.put_line(n.koord);
--            [ 49.019357, 33.644333],[ 49.071327, 33.607023],[ 49.126334, 33.620300],[ 49.079500, 33.441100],[ 49.036620, 33.433337],[ 48.975960, 33.317090],[ 48.911678, 33.338436],[ 48.732121, 33.066134],[ 48.675472, 32.884497],[ 48.717328, 32.649129],[ 48.748592, 32.519641],[ 48.523796, 32.260384],[ 48.518888, 32.124276],[ 48.332674, 31.514669],[ 48.241089, 31.408065],[ 47.573560, 31.323576],[ 47.304980, 31.018132],[ 46.828231, 30.759294]
     end loop;

        dbms_output.put_line(']
    }
});
myPolyline'||k.pp||'.options.set(''strokeColor'', ''#'||lpad(dec2hex(case when mod(k.pp,2)=0 then k.pp*8000 else 1532967-k.pp*8000  end),6,'0') ||''');
myPolyline'||k.pp||'.options.set(''strokeWidth'', ''3'');
myMap.geoObjects.add(myPolyline'||k.pp||');
');

    end loop;
    dbms_output.put_line('        }
    </script>
</head>
 
<body>
<div id="map" style="width:1200px; height:800px"></div>
</body>
 
</html>
');
end;
