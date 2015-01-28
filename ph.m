start_date = '2011-01-01';
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
[hax, ~, ~] = plotyy(timestamps, data.discharge, timestamps, data.ph);
datetick(hax(1));
datetick(hax(2));
%set(hax(2),'YLim',[0 50])
legend('Discharge', 'pH', 'Location', 'northwest');