classdef haddam_fdom < handle
    
    properties
        conn;
        usgs_timeseries;
        usgs_timeseries_timestamps;
        usgs_timeseries_filtered_discharge;
        fdom_corrected;
        fdom_corrected_timestamps;
        precipitation_data;
        precipitation_timestamps;
        start_date = '2012-01-01';
        end_date = '2015-01-01';
        
        event_start_dates = [];
        event_end_dates = [];
        event_total_sizes = [];
        
        metabasin_precipitation_totals;
    end
    
    methods(Static)
        function [hf] = start()
            hf = haddam_fdom();
            disp 'opening connection'
            hf.open_connection();
            disp 'loading usgs timeseries'
            hf.load_usgs_timeseries();
            disp 'loading fdom corrected'
            hf.load_fdom_corrected();
        end
        
        function [hf] = start_usgs_timeseries()
            hf = haddam_fdom();
            disp 'opening connection'
            hf.open_connection();
            disp 'loading usgs timeseries'
            hf.load_usgs_timeseries();
        end
        
        function [hf] = start_usgs_and_precip()
            hf = haddam_fdom();
            disp 'opening connection'
            hf.open_connection();
            disp 'loading usgs timeseries'
            hf.load_usgs_timeseries();
            disp 'loading precipitation'
            hf.load_precipitation();
            disp 'filtering discharge'
            hf.filter_discharge();
            disp 'finding precipitation events'
            hf.find_precipitation_events();
            
        end
    end
    
    methods
        
        function set_start_end_dates(obj, start_date, end_date)
            obj.start_date = start_date;
            obj.end_date = end_date;
        end
        
        function open_connection(obj)
            obj.conn = database('precipitation','matthewxi','','Vendor','PostgreSQL', 'Server', 'localhost');
        end
        
        function load_usgs_timeseries(obj)
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_timeseries_usgs '...
                'where cdom > 0 and ' ...
                'timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.start_date, obj.end_date);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries = curs.Data;
            obj.usgs_timeseries_timestamps = datenum(obj.usgs_timeseries.timestamp);
            
        end
        
        function load_usgs_timeseries_without_spring(obj)
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_timeseries_usgs '...
                'where cdom > 0 ' ...
                'and month > 5 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.start_date, obj.end_date);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries = curs.Data;
            obj.usgs_timeseries_timestamps = datenum(obj.usgs_timeseries.timestamp);
            
        end
        
        function load_fdom_corrected(obj)
            sql = ['select timestamp, t_turb_ife_ppb_qse ' ...
                'from haddam_fdom_usgs ' ...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') ' ...
                'order by timestamp asc'];
            sqlquery = sprintf(sql, obj.start_date, obj.end_date);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.fdom_corrected = curs.Data;
            obj.fdom_corrected_timestamps = datenum(obj.fdom_corrected.timestamp);
            
        end
        
        function plot_fdom_corrected_and_usgs_cdom(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.fdom_corrected_timestamps, obj.fdom_corrected.t_turb_ife_ppb_qse, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 100])
            set(hax(2),'YLim',[0 100])
            legend('FDOM Corrected', 'CDOM', 'Location', 'northwest');
        end
        
        function plot_usgs_cdom(obj)
            figure;
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick('x');
        end
        
        function plot_usgs_cdom_and_discharge(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick(hax(1));
            datetick(hax(2));
            %datetick('x');
        end
        
        function filter_discharge(obj)
            lpFilt = designfilt('lowpassiir', 'FilterOrder', 1, 'StopbandFrequency', .999, 'StopbandAttenuation', 100);
            fvtool(lpFilt);
            
            
            dataIn = obj.usgs_timeseries.discharge;
            % deal with empty data
            tf = isnan(dataIn);
            ix = 1:numel(dataIn);
            dataIn(tf) = interp1(ix(~tf),dataIn(~tf),ix(tf));
            
            %dataIn = rand([400 1]); dataOut = filter(lpFilt,dataIn);
            %dataIn = obj.usgs_timeseries.discharge;
            dataOut = filtfilt(lpFilt,dataIn);
            plot(dataOut);
            plot([dataIn, dataOut]);
            
            obj.usgs_timeseries_filtered_discharge = dataOut;
        end
        
        function plot_usgs_cdom_and_filtered_discharge(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick(hax(1));
            datetick(hax(2));
            %datetick('x');
        end
        
        function load_precipitation(obj)
            sqlquery = sprintf(['select total_precipitation, timestamp from total_macrowatershed_precipitation ' ...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') order by timestamp'], ...
                obj.start_date, obj.end_date);
            disp sqlquery;
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.precipitation_data = curs.Data;
            obj.precipitation_timestamps = datenum(obj.precipitation_data.timestamp)
        end
        
        function plot_precipitation(obj)
            figure;
            plot(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation, '-o');
            datetick('x');
        end
        
        function plot_precipitation_vs_discharge(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.precipitation_timestamps, obj.precipitation_data.total_precipitation, ...
                'plot', 'stem');
            %datetick(hax(1));
            %datetick(hax(2));
        end
        
        function plot_precipitation_vs_cdom(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, ...
                obj.precipitation_timestamps, obj.precipitation_data.total_precipitation, ...
                'plot', 'stem');
            %datetick(hax(1));
            %datetick(hax(2));
        end
        
        function find_precipitation_events(obj)
            
            % process for events
            in_event = false;
            event_threshold = 1000;
            event_start_date = 0;
            event_end_date = 0;
            event_total_size = 0;
            
            obj.event_start_dates = [];
            obj.event_end_dates = [];
            obj.event_total_sizes = [];
            
            for i=1:length(obj.precipitation_data.total_precipitation)
                precipitation = obj.precipitation_data.total_precipitation(i);
                
                if in_event == false
                    if precipitation > event_threshold
                        in_event = true;
                        event_start_date = obj.precipitation_timestamps(i);
                        event_total_size = precipitation;
                    end
                else
                    if precipitation > event_threshold
                        event_total_size = event_total_size + precipitation
                    else precipitation < event_threshold
                        in_event = false;
                        event_end_date = obj.precipitation_timestamps(i);
                        % event is over, put it into the arrays
                        obj.event_start_dates = [obj.event_start_dates event_start_date];
                        obj.event_end_dates = [obj.event_end_dates event_end_date];
                        obj.event_total_sizes = [obj.event_total_sizes event_total_size];
                    end
                end
            end
            
            figure;
            stem(obj.event_start_dates, obj.event_total_sizes, 'o')
            datetick('x');
            
            figure;
            [hax, ~, ~] = plotyy(obj.event_start_dates, obj.event_total_sizes, obj.precipitation_timestamps, obj.precipitation_data.total_precipitation,'stem', 'plot');
            legend('Precipitation Events', 'Precipitation');
            %datetick(hax(1));
            %datetick(hax(2));
            hLine1.LineStyle = '+';
            hLine2.LineStyle = '-o';
            
            
            
        end
        
        function plot_events_and_cdom(obj)
            % events and CDOM
            figure;
            [hax, hLine1, hLine2] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, obj.event_start_dates, obj.event_total_sizes, 'plot', 'stem');
            %set(hLine1,'color','red');
            %set(hLine2,'color','blue');
            title('Precipitation Events and CDOM');
        end
        
        function load_metabasin_totals(obj)
            sqlquery = sprintf('select metabasin_totals.gid, metabasin_totals.name, array_agg(to_char(timestamp, ''yyyymmdd'')) timestamps,  array_agg(sum) sums from metabasin_totals join metabasinpolygons on metabasin_totals.gid = metabasinpolygons.gid where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'')  group by metabasin_totals.gid, metabasin_totals.name, metabasinpolygons.sort order by sort',  ... 
                obj.start_date, obj.end_date)
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.metabasin_precipitation_totals = curs.Data
            
        end
        
         function load_metabasin_totals_skip_spring(obj)
            sqlquery = sprintf(['select metabasin_totals.gid, metabasin_totals.name, array_agg(to_char(timestamp, ''yyyymmdd'')) timestamps,  array_agg(sum) sums' ...
                ' from metabasin_totals join metabasinpolygons on metabasin_totals.gid = metabasinpolygons.gid' ...
                ' where month > 5 and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'')  group by metabasin_totals.gid, metabasin_totals.name, metabasinpolygons.sort order by sort'],  ... 
                obj.start_date, obj.end_date)
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.metabasin_precipitation_totals = curs.Data
            
        end
            
        function plot_metabasin_totals(obj)
            figure;
            hold on;
            for i=1:6
                subplot(6,1,i);
                totals = obj.metabasin_precipitation_totals.sums{i}.getArray;
                dates = obj.metabasin_precipitation_totals.timestamps{i}.getArray;
                dates = char(dates);
                timestamps = datenum(dates,'yyyymmdd');
                length(totals)
                length(dates)
                plot(timestamps, double(totals), '-');
                datetick('x');
                ylabel(obj.metabasin_precipitation_totals.name{i});
                ylim([0,800]);
                
            end
        end
        
    end
    
end

