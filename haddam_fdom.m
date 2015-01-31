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
        
        usgs_timeseries_subset;
        usgs_timeseries_subset_timestamps;
        
        % inverse modeling
        num_hysteresis_days = 14;
        K;
        y;
        a;
        fdom_predicted;
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
            close all;
            
        end
        
        function [hf] = start_usgs_and_precip_analysis()
            hf = haddam_fdom.start_usgs_and_precip();
            hf.plot_precipitation_vs_cdom
            hf.plot_precipitation_vs_discharge
        end
        
        function [hf] = start_usgs_and_inverse_model()
            hf = haddam_fdom.start_usgs_and_precip();
            hf.build_predictor_matrix;
            hf.solve_inverse;
            hf.predict_fdom;
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
            curs.Data
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
            f = figure;
            set(gca,'Position',[.05 .05 .9 .9]);
            plotedit on;
            set(f, 'Position', [0 0 1600 300]);
            %[hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
            %   obj.precipitation_timestamps, obj.precipitation_data.total_precipitation, ...
            %   'plot', 'stem');
            %datetick(hax(1));
            %datetick(hax(2));
            
            subplot(2,1,1);
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge);
            title('Discharge');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            datetick('x');
            
            subplot(2,1,2);
            stem(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            title('Precipitation');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            datetick('x');
        end
        
        function plot_precipitation_vs_cdom(obj)
            figure;
            %[hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, ...
            %    obj.precipitation_timestamps, obj.precipitation_data.total_precipitation, ...
            %    'plot', 'stem');
            %datetick(hax(1));
            %datetick(hax(2));
            %xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            
            subplot(2,1,1);
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            title('CDOM');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            datetick('x');
            
            subplot(2,1,2);
            stem(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            title('Precipitation');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            datetick('x');
        end
        
        function find_precipitation_events(obj)
            
            % process for events
            in_event = false;
            event_threshold = 500;
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
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            title('Precipitation Events and CDOM');
        end
        
        function plot_events_and_discharge(obj)
            % events and CDOM
            f = figure;
            set(gca,'Position',[.05 .05 .9 .9]);
            plotedit on;
            set(f, 'Position', [0 0 1600 300]);
            %[hax, hLine1, hLine2] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, obj.event_start_dates, obj.event_total_sizes, 'plot', 'stem');
            %set(hLine1,'color','red');
            %set(hLine2,'color','blue');
            %datetick(hax(1));
            %datetick(hax(2));
            subplot(2,1,1);
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge);
            subplot(2,1,2);
            stem(obj.event_start_dates, obj.event_total_sizes);
            title('Precipitation Events');
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
            f=figure;
            set(gca,'Position',[.05 .05 .9 .9]);
            plotedit on;
            set(f, 'Position', [0 0 1600 800]);
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
        
        function build_predictor_matrix(obj)
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_download_usgs '...
                'where cdom > 0 ' ...
                'and month > 5 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.start_date, obj.end_date);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            % y = a3 * p3 + a4 * p4 + a5 * p5 + c
            % pi is precipitation total i days ago
            
            sample_count = size(obj.usgs_timeseries_subset_timestamps);
            sample_count = sample_count(1);
            %sample_count = 10;
            obj.K = zeros(sample_count, obj.num_hysteresis_days + 2);
            obj.y = zeros(sample_count, 1);
            
            % organize the precipitation for lookup
            
            x_map = containers.Map(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            x_map
            
            for i=1:sample_count
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                precip_totals = zeros(obj.num_hysteresis_days, 1);
                for j = 1:obj.num_hysteresis_days
                    d = datenum(date - days(j));
                    precip_totals(j) = 0;
                    if isKey(x_map, d)
                        precip_totals(j) = x_map(d);
                    end
                end
                
                obj.K(i, 1) = 1;
                for j = 1:obj.num_hysteresis_days
                    obj.K(i, j+1) = precip_totals(j);
                end
                
                d = str2double(datestr(date, 'dd'));
                
                %
                % seasonal effect - autumn
                %
                
                % this one didn't really work.
                %obj.K(i, obj.num_hysteresis_days+2) = (d-100)^2;
                
                % just try adding some extra for nov, dec since we observe
                % this
                if( str2double(datestr(date, 'mm')) > 10)
                    obj.K(i, obj.num_hysteresis_days+2) = 1;
                else
                    obj.K(i, obj.num_hysteresis_days+2) = 0;
                end
                
                obj.y(i) = obj.usgs_timeseries_subset.cdom(i);
            end
            
            obj.K
            
        end
        
        function solve_inverse(obj)
            obj.K
            Kt = transpose(obj.K);
            obj.a = (Kt * obj.K) \ (Kt * obj.y);
            obj.a
        end
        
        function predict_fdom(obj)
            syms fdom p3 p4 p5;
            obj.a
            
            % load the averaged values
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_download_usgs '...
                'where cdom > 0 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.start_date, obj.end_date);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            % y = a3 * p3 + a4 * p4 + a5 * p5 + c
            % pi is precipitation total i days ago
            
            sample_count = size(obj.usgs_timeseries_subset_timestamps);
            
            % organize the precipitation for lookup
            x_map = containers.Map(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            
            
            obj.fdom_predicted = zeros(sample_count);
            
            for i=1:sample_count(1)
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                precip_totals = zeros(obj.num_hysteresis_days, 1);
                for j = 1:obj.num_hysteresis_days
                    d = datenum(date - days(j));
                    precip_totals(j) = 0;
                    if isKey(x_map, d)
                        precip_totals(j) = x_map(d);
                    end
                end
                
                % add up the predictor variables
                obj.fdom_predicted(i) = obj.a(1);
                for j = 2:obj.num_hysteresis_days
                    obj.fdom_predicted(i) = obj.fdom_predicted(i) + obj.a(j) * precip_totals(j);
                end
                d = str2double(datestr(date, 'dd'));
                
                % parabolic didn't work very well
                % obj.fdom_predicted(i) = obj.fdom_predicted(i) +  obj.a(obj.num_hysteresis_days + 2) * (d-100)^2;
                
                if( str2double(datestr(date, 'mm')) > 10)
                    
                    obj.fdom_predicted(i) = obj.fdom_predicted(i) +  obj.a(obj.num_hysteresis_days + 2)
                end
            end
        end
        
        function plot_prediction(obj)
            figure();
            
            subplot(4,1,1);
            plot(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            title('Sensor CDOM');
            
            subplot(4,1,2);
            plot(obj.usgs_timeseries_subset_timestamps, obj.fdom_predicted);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            title('Modeled CDOM');
            
            
            subplot(4,1,3);
            plot(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            title('Precipitation');
            
            subplot(4,1,4);
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom, ...
                obj.usgs_timeseries_subset_timestamps, obj.fdom_predicted);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 60])
            set(hax(2),'YLim',[0 60])
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            
        end
        
        function plot_prediction_yy(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom, ...
                obj.usgs_timeseries_subset_timestamps, obj.fdom_predicted);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 60])
            set(hax(2),'YLim',[0 60])
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
        end
        
        function inverse_model(obj)
            obj.build_predictor_matrix;
            obj.solve_inverse;
            obj.predict_fdom;
            obj.plot_prediction;
        end
    end
    
end

