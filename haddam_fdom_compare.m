close all;
start_date = '2012-01-01';
end_date = '2013-01-01';

% use this to fill in the empty days
% select * from generate_series('2011-09-01'::timestamp, '2011-12-01', '1 day');

conn = database('precipitation','matthewxi','','Vendor','PostgreSQL', 'Server', 'localhost')

sqlquery = sprintf('select timestamp,cdom,discharge,gage_height,ph from measurements where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') order by timestamp asc', start_date, end_date);
curs = exec(conn,sqlquery);
setdbprefs('DataReturnFormat','structure');
curs = fetch(curs);

data = curs.Data;
timestamps = datenum(data.timestamp);



figure;
[hax, ~, ~] = plotyy(timestamps, data.discharge, timestamps, data.cdom);
datetick(hax(1));
datetick(hax(2));
set(hax(2),'YLim',[0 50])
legend('Discharge', 'CDOM', 'Location', 'northwest');


% Adjusted FDOM data
sql = ['select timestamp, t_turb_ife_ppb_qse ' ...
                    'from haddam_fdom_usgs ' ...
                     'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') ' ...
                     'order by timestamp asc'];
sqlquery = sprintf(sql, start_date, end_date);
curs = exec(conn,sqlquery);
setdbprefs('DataReturnFormat','structure');
curs = fetch(curs);
fdom_data = curs.Data;
fdom_timestamps = datenum(fdom_data.timestamp);

figure;
plot(fdom_timestamps, fdom_data.t_turb_ife_ppb_qse);
datetick('x');


figure;
[hax, ~, ~] = plotyy(fdom_timestamps, fdom_data.t_turb_ife_ppb_qse, timestamps, data.cdom);
%datetick(hax(1));
%datetick(hax(2));
set(hax(1),'YLim',[0 50])
set(hax(2),'YLim',[0 50])
legend('FDOM Corrected', 'CDOM', 'Location', 'northwest');



sqlquery = sprintf('select timestamp,cdom,discharge from haddam_timeseries_usgs where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') order by timestamp asc', start_date, end_date);
sqlquery
sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_timeseries_usgs ' ...
                    'where cdom != 0 ' ...
                    'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') ' ...
                    'order by timestamp asc'], start_date, end_date);
sqlquery            
curs = exec(conn,sqlquery);
setdbprefs('DataReturnFormat','structure');
curs = fetch(curs);

haddam_timeseries_usgs = curs.Data;
haddam_timeseries_usgs_timestamps = datenum(haddam_timeseries_usgs.timestamp);

figure;
plot(haddam_timeseries_usgs_timestamps, haddam_timeseries_usgs.cdom);
datetick('x');

figure;
plot(timestamps, data.cdom);
datetick('x');


figure;
[hax, ~, ~] = plotyy(timestamps, data.cdom, haddam_timeseries_usgs_timestamps, haddam_timeseries_usgs.cdom);
%datetick(hax(1));
%datetick(hax(2));
set(hax(1),'YLim',[0 50])
set(hax(2),'YLim',[0 50])
legend('Data From Pete', 'Haddam Timeseries', 'Location', 'northwest');
