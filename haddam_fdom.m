classdef haddam_fdom < handle
    
    properties
        % configuration
        seasonal_mode = 3; % modeled | step | 12 month, constants below
        enable_y_intercept = false;
        
        % constants
        seasonal_mode_none = 0;
        seasonal_mode_step = 1;
        seasonal_mode_modeled = 2;
        seasonal_mode_12_month = 3;
        
        % vars
        conn;
        usgs_timeseries;
        usgs_timeseries_timestamps;
        usgs_timeseries_filtered_discharge;
        usgs_timeseries_filtered_doc_mass_flow;

        fdom_corrected;
        fdom_corrected_timestamps;
        precipitation_data;
        precipitation_timestamps;
        
        seasonal_doc_julian;
        
        start_date = '2012-01-01';
        end_date = '2015-01-01';
        parameterization_start_date = '2012-01-01';
        parameterization_end_date = '2015-01-01';
        
        event_start_dates = [];
        event_end_dates = [];
        event_total_sizes = [];
        
        metabasin_precipitation_totals;
        
        usgs_timeseries_subset;
        usgs_timeseries_subset_timestamps;
        
        % inverse modeling
        num_history_days = 14;
        K;
        y;
        a;
        predicted_values;
    end
    
    methods(Static)
                
        function [dayOfYear] = day_of_year(in_date_num)
            prevYear = datenum(year(datetime(in_date_num, 'ConvertFrom', 'datenum'))-1, 12,31);
            dayOfYear = in_date_num-prevYear;
        end
        
        
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
            %disp 'filtering discharge'
            %hf.filter_discharge();
            disp 'finding precipitation events'
            hf.find_precipitation_events();
            close all;
            
        end
        
        function [hf] = start_usgs_and_precip_analysis()
            hf = haddam_fdom.start_usgs_and_precip();
            hf.plot_precipitation_vs_cdom
            hf.filter_discharge
            hf.plot_precipitation_vs_discharge
        end
        
        function [hf] = start_inverse_model()
            hf = haddam_fdom();
            hf.open_connection();
            hf.load_usgs_timeseries();
            hf.load_precipitation();
            hf.load_seasonal_doc_julian();
            hf.build_predictor_matrix;
            hf.solve_inverse;
            hf.predict_fdom;
            hf.plot_prediction;
        end
        
        function [hf] = start_usgs_and_inverse_model_metabasins()
            hf = haddam_fdom.start_usgs_and_precip();
            hf.load_metabasin_totals;
            hf.inverse_model_metabasins;
        end
        
        
    end
    
    methods
        
        % could use this strategy to avoid reloading the data when class
        % refreshes
        function global_scope_var(obj)
            global x
            x= 2
        end
        
        function set_start_end_dates(obj, start_date, end_date)
            obj.start_date = start_date;
            obj.end_date = end_date;
        end
        
        function open_connection(obj)
            obj.conn = database('precipitation','matthewxi','','Vendor','PostgreSQL', 'Server', 'localhost');
        end
        
        function load_usgs_timeseries(obj)
            sqlquery = sprintf(['select timestamp,cdom,discharge,doc_mass_flow,doxygen,nitrate,conductance,turbidity,ph,temperature from haddam_timeseries_usgs_extended '...
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
        
        function load_seasonal_doc_julian(obj)
           obj.seasonal_doc_julian = csvread('prepared_seasonal_doc.csv');
        end
        
        function plot_fdom_corrected(obj)
             figure;
            plot(obj.fdom_corrected_timestamps, obj.fdom_corrected.t_turb_ife_ppb_qse);
            datetick('x');
            legend('FDOM Corrected', 'Location', 'northwest');
        end
        
        function plot_fdom_corrected_and_usgs_cdom(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.fdom_corrected_timestamps, obj.fdom_corrected.t_turb_ife_ppb_qse, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 100])
            set(hax(2),'YLim',[0 100])
            legend('FDOM Corrected', 'FDOM', 'Location', 'northwest');
            
            
            figure;
            subplot(2,1,1)
            plot(obj.fdom_corrected_timestamps, obj.fdom_corrected.t_turb_ife_ppb_qse);
            datetick('x');
            legend('FDOM Corrected', 'Location', 'northwest');
            
            subplot(2,1,2);
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick('x');
            legend('USGS FDOM', 'Location', 'northwest');
        end
        
        
        function plot_usgs(obj, field)
            figure;
            plot(obj.usgs_timeseries_timestamps, getfield(obj.usgs_timeseries, field));
            datetick('x');
        end
        
        function plot_usgs_yy(obj, field1, field2)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, getfield(obj.usgs_timeseries, field1), ...
                obj.usgs_timeseries_timestamps, getfield(obj.usgs_timeseries, field2));
            datetick(hax(1));
            datetick(hax(2));
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
        
        function plot_usgs_cdom_and_mass_flow(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.doc_mass_flow, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick(hax(1));
            datetick(hax(2));
            legend('DOC Mass Flow', 'CDOM Signal');

            %datetick('x');
        end
        
        function plot_usgs_discharge_and_mass_flow(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.doc_mass_flow, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.discharge);
            datetick(hax(1));
            datetick(hax(2));
            legend('DOC Mass Flow', 'Discharge');

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
        
        function filter_doc_mass_flow(obj)
            lpFilt = designfilt('lowpassiir', 'FilterOrder', 1, 'StopbandFrequency', .999, 'StopbandAttenuation', 100);
            fvtool(lpFilt);
            
            
            dataIn = obj.usgs_timeseries.doc_mass_flow;
            % deal with empty data
            tf = isnan(dataIn);
            ix = 1:numel(dataIn);
            dataIn(tf) = interp1(ix(~tf),dataIn(~tf),ix(tf));
            
            %dataIn = rand([400 1]); dataOut = filter(lpFilt,dataIn);
            %dataIn = obj.usgs_timeseries.discharge;
            dataOut = filtfilt(lpFilt,dataIn);
            plot(dataOut);
            plot([dataIn, dataOut]);
            
            obj.usgs_timeseries_filtered_doc_mass_flow = dataOut;
        end
        
        function plot_filtered_discharge(obj)
            figure;
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge);
            datetick('x');
        end
        
        function plot_vs_filtered_discharge(obj, field)
           figure;
           [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, getfield(obj.usgs_timeseries, field) );
             datetick(hax(1));
            datetick(hax(2));
%            datetick('x', 'yy', 'keeplimits', 'keepticks');
        end
        
        function plot_all_vs_filtered_discharge(obj)
           figure;
           
           subplot(6, 1, 1);
           [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom );
            datetick(hax(1));
            datetick(hax(2));
            set(hax(2),'ylim',[0 50]);

            subplot(6, 1, 2);
           [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.conductance );
            datetick(hax(1));
            datetick(hax(2));
            
            subplot(6, 1, 3);
           [hax, ~, y1] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.turbidity );
            set(hax(2),'ylim',[0 100]);
            datetick(hax(1));
            datetick(hax(2));
            
            subplot(6, 1, 4);
           [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.nitrate );
            datetick(hax(1));
            datetick(hax(2));
            
            subplot(6, 1, 5);
           [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.doxygen );
            datetick(hax(1));
            datetick(hax(2));
            set(hax(2),'ylim',[5 19]);

            
            subplot(6, 1, 6);
           [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.ph );
            datetick(hax(1));
            datetick(hax(2));
            set(hax(2),'ylim',[6.5 9]);

        end
        
        
        s
        function plot_usgs_cdom_and_filtered_discharge(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom);
            datetick(hax(1));
            datetick(hax(2));
            %datetick('x');
        end
        
        function plot_filtered_doc_mass_flow_and_filtered_discharge(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_doc_mass_flow);
            datetick(hax(1));
            datetick(hax(2));
            legend('Discharge', 'DOC Mass Flow');
            %datetick('x');
             q
            figure;
            subplot(2,1,1);
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge);
            title('Smoothed Discharge ft^3/s');
            
            subplot(2,1,2);
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_doc_mass_flow);
            title('Smoothed DOC Mass Flow g/s');
            
        end
        
        
         function plot_filtered_doc_mass_flow_and_usgs_cdom(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_doc_mass_flow);
            datetick(hax(1));
            datetick(hax(2));
            legend('CDOM Sensor', 'DOC Mass Flow');
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
            figure
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
               obj.precipitation_timestamps, obj.precipitation_data.total_precipitation, ...
               'plot', 'stem');
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            
            f = figure;
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
            title('FDOM');
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
            event_threshold = 900;
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
            % events and FDOM
            figure;
            [hax, hLine1, hLine2] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, obj.event_start_dates, obj.event_total_sizes, 'plot', 'stem');
            %set(hLine1,'color','red');
            %set(hLine2,'color','blue');
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Precipitation Events and FDOM');
        end
        
        function plot_events_and_discharge(obj)
            % events and FDOM
            f = figure;
            set(gca,'Position',[.05 .05 .9 .9]);
            plotedit on;
            set(f, 'Position', [0 0 1600 300]);
            [hax, hLine1, hLine2] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, obj.event_start_dates, obj.event_total_sizes, 'plot', 'stem');
            %set(hLine1,'color','red');
            %set(hLine2,'color','blue');
            datetick(hax(1), 'keeplimits');
            datetick(hax(2), 'keeplimits');
            
            f=figure;
            set(gca,'Position',[.05 .05 .9 .9]);
            plotedit on;
            set(f, 'Position', [0 0 1600 300]);
            subplot(2,1,1);            
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge);
            subplot(2,1,2);
            stem(obj.event_start_dates, obj.event_total_sizes);
            title('Precipitation Events');
        end
        
        
        function plot_events_and_discharge_and_cdom(obj)
             figure;
             subplot(2,1,1);

            [hax, hLine1, hLine2] = plotyy( obj.event_start_dates, obj.event_total_sizes, obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, 'stem', 'plot');
            set(hLine1,'color','red');
            set(hLine2,'color','blue');
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Precipitation Events and FDOM');
            
            subplot(2,1,2);
            [hax, hLine1, hLine2] = plotyy( ...
                obj.event_start_dates, obj.event_total_sizes, ...
                obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, ...
                'stem', 'plot');
            set(hLine1,'color','red');
            set(hLine2,'color','blue');
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Precipitation Events and Discharge');  
        end
        
        function load_metabasin_totals(obj)
            sqlquery = sprintf( ...
                ['select metabasin_totals.gid, metabasinpolygons.name, array_agg(to_char(timestamp, ''yyyymmdd'')) timestamps,  array_agg(sum) sums' ...
                ' from metabasin_totals join metabasinpolygons on metabasin_totals.gid = metabasinpolygons.gid' ...
                ' where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'')' ...
                ' group by metabasin_totals.gid, metabasinpolygons.name, metabasinpolygons.sort order by sort'],  ...
                obj.start_date, obj.end_date);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.metabasin_precipitation_totals = curs.Data
            
        end
        
        function load_metabasin_totals_skip_spring(obj)
            sqlquery = sprintf(['select metabasin_totals.gid, metabasinpolygons.name, array_agg(to_char(timestamp, ''yyyymmdd'')) timestamps,  array_agg(sum) sums' ...
                ' from metabasin_totals join metabasinpolygons on metabasin_totals.gid = metabasinpolygons.gid' ...
                ' where month > 5 and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'')  group by metabasin_totals.gid, metabasinpolygons.name, metabasinpolygons.sort order by sort'],  ...
                obj.start_date, obj.end_date)
            sqlquery
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
        
        function build_inversion_fdom(obj)
            s_date = obj.parameterization_start_date;
            e_date = obj.parameterization_end_date;
            
            % may want to specify different parameterization date range
            % from prediction range
            %s_date = '2012-01-01';
            %e_date = '2014-01-01';
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_download_usgs '...
                'where cdom > 0 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], s_date, e_date);
                            % 'and month > 5 ' ...

            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
            obj.y = obj.usgs_timeseries_subset.cdom;
        end
        
        function build_predictor_matrix(obj, timestamps)
            
            % y = a3 * p3 + a4 * p4 + a5 * p5 + c
            % pi is precipitation total i days ago
            
            sample_count = size(timestamps);
            sample_count = sample_count(1);
            %sample_count = 10;
            obj.K = zeros(sample_count, obj.num_history_days + 1);  % should size based off seasonal mode
            obj.y = zeros(sample_count, 1);
            
            % organize the precipitation for lookup
            x_map = containers.Map(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            
            for i=1:sample_count
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                precip_totals = zeros(obj.num_history_days, 1);
                for j = 1:obj.num_history_days
                    if(j == 1)
                        d = date;  % start with the current day
                    else
                        d = datenum(date - days(j-1));
                    end
                    precip_totals(j) = 0;
                    if isKey(x_map, d)
                        precip_totals(j) = x_map(d);
                    end
                end
                
                offset = 0;
                if(obj.enable_y_intercept)
                    offset = 1;
                    obj.K(i, 1) = 1;  % so an idea is to change the forward problem to remove y offset
                end
                
                for j = offset+1:obj.num_history_days+offset
                    obj.K(i, j) = precip_totals(j-offset);
                end
                
                d = str2double(datestr(date, 'dd'));
                
                %
                % seasonal effect - autumn
                %
                
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                        obj.K(i, obj.num_history_days+offset+1) = 1;
                    else
                        obj.K(i, obj.num_history_days+offset+1) = 0;
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    haddam_fdom.day_of_year(date)
                    obj.K(i, obj.num_history_days+offset+1) = obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;  % multiply by 10000 to avoid matrix precision problems
                
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    month = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = obj.num_history_days+offset+(m + 1 - start_month);
                        if(m == month)
                           obj.K(i, index) = 1; 
                        else
                           obj.K(i, index) = 0;
                        end
                    end
                else
                    obj.K(i, obj.num_history_days+1) = 1;
                end
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
            
            obj.predict(obj.usgs_timeseries_subset_timestamps);
        end
            
            
        function predicted_values = predict(obj, timestamps)
            syms fdom p3 p4 p5;
            
            % y = a3 * p3 + a4 * p4 + a5 * p5 + c
            % pi is precipitation total i days ago
            
            sample_count = size(timestamps);
            sample_count
            
            % organize the precipitation for lookup
            x_map = containers.Map(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            
            
            obj.predicted_values = zeros(sample_count);
            
            for i=1:sample_count(1)
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                precip_totals = zeros(obj.num_history_days, 1);
                for j = 1:obj.num_history_days
                    if(j==1)
                        d = date;
                    else
                        d = datenum(date - days(j));
                    end
                    precip_totals(j) = 0;
                    if isKey(x_map, d)
                        precip_totals(j) = x_map(d);
                    end
                end
                
                
                offset = 0;
                if(obj.enable_y_intercept)
                    offset = 1;
                    obj.predicted_values(i) = obj.a(1);
                end
                
                % add up the predictor variables
                for j = 1:obj.num_history_days
                    obj.predicted_values(i) = obj.predicted_values(i) + obj.a(j+offset) * precip_totals(j);
                end
                
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                       obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + offset +1);
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + offset + 1)*obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;
                 
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    month = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = j + offset + (m + 1 - start_month);
                        if(m == month)
                           obj.predicted_values(i) = obj.predicted_values(i) + obj.a(index);
                        end
                    end
                end
                
                % debuging
                % obj.predicted_values(i) = obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2);
            end
            predicted_values = obj.predicted_values;
        end
        
         function build_inversion_discharge(obj)
            s_date = obj.parameterization_start_date;
            e_date = obj.parameterization_end_date;
            
            % may want to specify different parameterization date range
            % from prediction range
            %s_date = '2012-01-01';
            %e_date = '2012-02-01';
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_download_usgs '...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], s_date, e_date);
                            % 'and month > 5 ' ...

            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
            obj.y =  obj.usgs_timeseries_subset.discharge;
            obj.y(isnan(obj.y))=0;
         end
         
 
        
        function predict_discharge(obj)
            % load the averaged values
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_download_usgs '...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.start_date, obj.end_date);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            obj.predict(obj.usgs_timeseries_subset_timestamps);
        end
            
        
        function build_inversion_conductance(obj)
            s_date = obj.parameterization_start_date;
            e_date = obj.parameterization_end_date;
            
            % may want to specify different parameterization date range
            % from prediction range
            %s_date = '2012-01-01';
            %e_date = '2012-02-01';
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            sqlquery = sprintf(['select timestamp,conductance_mean as conductance from haddam_download_usgs '...
                'where conductance_mean > 0 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], s_date, e_date);
                            % 'and month > 5 ' ...

            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            disp('Building Predictor Matrix');
            obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
            disp('Built Predictor Matrix');
            obj.y =  obj.usgs_timeseries_subset.conductance;
            obj.y(isnan(obj.y))=0;
        end
        
        function predict_conductance(obj)
            % this is just getting the timestamps
            sqlquery = sprintf(['select timestamp,conductance_mean as conductance from haddam_download_usgs '...
                'where conductance_mean > 0 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.start_date, obj.end_date);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            obj.predict(obj.usgs_timeseries_subset_timestamps);
        end
        
       function inverse_model_cdom(obj)
           obj.seasonal_mode = obj.seasonal_mode_12_month;
           obj.build_inversion('cdom');
           obj.solve_inverse
           obj.predict(obj.usgs_timeseries_subset_timestamps);
           obj.plot_prediction(  obj.usgs_timeseries_subset.value );
       end
        
          
       function inverse_model_conductance(obj)
           obj.seasonal_mode = obj.seasonal_mode_12_month;
           obj.build_inversion('conductance_mean');
           obj.solve_inverse
           obj.predict(obj.usgs_timeseries_subset_timestamps);
           obj.plot_prediction(  obj.usgs_timeseries_subset.value );
        end
        
       function inverse_model_turbidity(obj)
           obj.seasonal_mode = obj.seasonal_mode_12_month;
           obj.build_inversion('turbidity');
           obj.solve_inverse
           obj.predict(obj.usgs_timeseries_subset_timestamps);
           obj.plot_prediction(  obj.usgs_timeseries_subset.value );
       end
       
       function inverse_model_nitrate(obj)
           obj.seasonal_mode = obj.seasonal_mode_12_month;
           obj.build_inversion('nitrate');
           obj.solve_inverse
           obj.predict(obj.usgs_timeseries_subset_timestamps);
           obj.plot_prediction(  obj.usgs_timeseries_subset.value );
       end
       
        function inverse_model_do(obj)
           obj.seasonal_mode = obj.seasonal_mode_12_month;
           obj.build_inversion('doxygen');
           obj.solve_inverse
           obj.predict(obj.usgs_timeseries_subset_timestamps);
           obj.plot_prediction(  obj.usgs_timeseries_subset.value );
       end
        
        
       function build_inversion(obj, field)
            s_date = obj.parameterization_start_date;
            e_date = obj.parameterization_end_date;
            
            % may want to specify different parameterization date range
            % from prediction range
            %s_date = '2012-01-01';
            %e_date = '2012-02-01';
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            sqlquery = sprintf(['select timestamp, %s as value from haddam_download_usgs '...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], field, s_date, e_date);
                            % 'and month > 5 ' ...
                            %                 'and value > 0 ' ...


            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            disp('Building Predictor Matrix');
            obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
            disp('Built Predictor Matrix');
            obj.y =  obj.usgs_timeseries_subset.value;
            obj.y(isnan(obj.y))=0;
        end 
       
        function predict_field(obj, field)
            % this is just getting the timestamps
            sqlquery = sprintf(['select timestamp,%s as value from haddam_download_usgs '...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], field, obj.start_date, obj.end_date);
            
            %                 'where value > 0 ' ...

            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            
            obj.predict(obj.usgs_timeseries_subset_timestamps);
        end
        
        function plot_month_coeffs(obj)
           figure;
           offset = 0;
           if(obj.enable_y_intercept)
               offset = 1;
           end 
           plot(obj.a(15+offset:end) + obj.a(1));
        end
        
        function plot_prediction_cdom(obj)
           obj.plot_prediction( obj.usgs_timeseries_subset.cdom ); 
        end
        
        function plot_prediction_discharge(obj)
            obj.plot_prediction(  obj.usgs_timeseries_subset.discharge);
        end
        
        function plot_prediction(obj, observed)
            figure();
            max_observed = max(observed);
            %max_observed = 100;
            
            subplot(4,1,1);
            plot(obj.usgs_timeseries_subset_timestamps, observed);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            ylim([0,max_observed]);
            title('Sensor Values');
            
            subplot(4,1,2);
            plot(obj.usgs_timeseries_subset_timestamps, obj.predicted_values);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            ylim([0,max_observed]);
            title('Modeled Values');
            
            
            subplot(4,1,3);
            plot(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            title('Precipitation');
            
            subplot(4,1,4);
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_subset_timestamps, observed, ...
                obj.usgs_timeseries_subset_timestamps, obj.predicted_values);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 max_observed])
            set(hax(2),'YLim',[0 max_observed])
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Comparison');
            legend('Sensor Values', 'Modeled Values',  'Location', 'northwest');
            
        end
        
        function plot_prediction_yy(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom, ...
                obj.usgs_timeseries_subset_timestamps, obj.predicted_values);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 60])
            set(hax(2),'YLim',[0 60])
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Modeled and Sensor FDOM');
            legend('Sensor FDOM', 'Modeled FDOM');
            
            %figure;
            %[hax, ~, ~] = plotyy(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.discharge, ...
            %    obj.usgs_timeseries_subset_timestamps, obj.predicted_values);
            %datetick(hax(1));
            %datetick(hax(2));
            %set(hax(2),'YLim',[0 60])
            %set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            %title('Modeled FDOM and Discharge');
            %legend('Discharge', 'Modeled FDOM');
            
            %covariance_matrix = inv(transpose(obj.K) * obj.K)
            % this doesn't work properly b/c inputs (precip) is not
            % normalized per std deviation vs. day of year variable
        end
        
        
        function plot_history_effect(obj)
            A = obj.a(:,1);
            A = A(1:obj.num_history_days);
            figure;
            hold on;
            plot(0:obj.num_history_days-1, A(:,1));
            title('Coefficients of precipitation influence by number of days in the past');
            
            hline = refline([0 0]);
            hline.Color = 'r';
            hold off;
            
        end
        
        function inverse_model(obj)
            obj.build_predictor_matrix;
            obj.solve_inverse;
            obj.predict_fdom;
            obj.plot_prediction;
        end
        
        function build_predictor_matrix_metabasins(obj)
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_download_usgs '...
                'where cdom > 0 ' ...
                'and month > 5 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.parameterization_start_date, obj.parameterization_end_date);
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
            obj.K = zeros(sample_count, obj.num_history_days * 6 + 2); % * 6 for metabasins
            obj.y = zeros(sample_count, 1);
            
            % organize the precipitation for lookup
            
            basins = 6;
            x_maps = java.util.Vector(basins);
            %x_maps;
            for k = 1 : basins
                totals = obj.metabasin_precipitation_totals.sums{k}.getArray;
                totals = double(totals);
                dates = obj.metabasin_precipitation_totals.timestamps{k}.getArray;
                dates = char(dates);
                timestamps = datenum(dates,'yyyymmdd');
                map = java.util.Hashtable;
                size(totals, 1)
                for i = 1:size(totals, 1)
                    map.put(timestamps(i), totals(i));
                end
                %map
                
                x_maps.add(map);
                
            end
            
            
            for i=1:sample_count
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                precip_totals = zeros(obj.num_history_days, 6);
                for j = 1:obj.num_history_days
                    d = datenum(date - days(j-1));
                    for k = 1 : basins
                        precip_totals(j, k) = 0;
                        x_map = x_maps.get(k-1);
                        if x_map.containsKey(d)
                            precip_totals(j, k) = x_map.get(d);
                        end
                    end
                end
                
                
                obj.K(i, 1) = 1;
                for k = 1 : basins
                    for j = 1:obj.num_history_days
                        % assign X values for inverse model
                        % some basin and day totals are set to zero 
                        % because we know they could not have any effect.
                        
                        % doing this leads to a singular matrix
                        % need to actually change the forward problem
                        %basin = k;
                        %if j == 1 && (basin == 1 || basin == 2 || basin == 3 || basin == 4)
                        %     obj.K(i, ((k-1)*obj.num_history_days) + j +1) = 0;
                        %elseif j == 2 && (basin == 1 || basin == 2)
                        %       obj.K(i, ((k-1)*obj.num_history_days) + j +1) = 0;
                        %else
                            obj.K(i, ((k-1)*obj.num_history_days) + j +1) = precip_totals(j, k);
                        %end
                    end
                end
                
                d = str2double(datestr(date, 'dd'));
                    
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                        obj.K(i, basins*obj.num_history_days+offset+1) = 1;
                    else
                        obj.K(i, basins*obj.num_history_days+offset+1) = 0;
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    haddam_fdom.day_of_year(date)
                    obj.K(i, basins*obj.num_history_days+offset+1) = obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;  % multiply by 10000 to avoid matrix precision problems
                    
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    month = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = basins*obj.num_history_days+offset+(m + 1 - start_month);
                        if(m == month)
                            obj.K(i, index) = 1;
                        else
                            obj.K(i, index) = 0;
                        end
                    end
                end
                
                obj.y(i) = obj.usgs_timeseries_subset.cdom(i);
            end
            
            obj.K
            
        end
        
        function predict_fdom_metabasins(obj)
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
            basins = 6;
            x_maps = java.util.Vector(basins);
            for k = 1 : basins
                totals = obj.metabasin_precipitation_totals.sums{k}.getArray;
                totals = double(totals);
                dates = obj.metabasin_precipitation_totals.timestamps{k}.getArray;
                dates = char(dates);
                timestamps = datenum(dates,'yyyymmdd');
                map = java.util.Hashtable;
                size(totals, 1)
                for i = 1:size(totals, 1)
                    map.put(timestamps(i), totals(i));
                end
                
                x_maps.add(map);
                
            end
            
            
            obj.predicted_values = zeros(sample_count);
            
            for i=1:sample_count(1)
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                obj.predicted_values(i) = obj.a(1);
                
                for k = 1:basins
                    
                    precip_totals = zeros(obj.num_history_days, 1);
                    for j = 1:obj.num_history_days
                        d = datenum(date - days(j));
                        precip_totals(j) = 0;
                        
                        x_map = x_maps.get(k-1);
                        if x_map.containsKey(d)
                            precip_totals(j) = x_map.get(d);
                        end
                        
                    end
                    
                    % add up the predictor variables
                    for j = 1:obj.num_history_days
                        obj.predicted_values(i) = obj.predicted_values(i) + obj.a((k-1)*obj.num_history_days +  j + 1) * precip_totals(j);
                    end
                    
                end
                
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                       obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + offset +1);
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + offset + 1)*obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;
                 
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    month = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = j + offset + (m + 1 - start_month);
                        if(m == month)
                           obj.predicted_values(i) = obj.predicted_values(i) + obj.a(index);
                        end
                    end
                end
                
            end
        end
        
        function inverse_model_metabasins(obj)
            obj.build_predictor_matrix_metabasins;
            obj.solve_inverse;
            obj.predict_fdom_metabasins;
            obj.plot_prediction;
            obj.plot_prediction_yy;
        end
        
        function plot_history_effect_metabasins(obj)
            
            A = obj.a(:,1);
            A = A(2:end-1);
            figure;
            for k = 1:3
                subplot(3,1,k);
                hold on;
                
                index = 2*(k-1) + 1;
                
                legends = [obj.metabasin_precipitation_totals.name(index), obj.metabasin_precipitation_totals.name(index+1)];
                
                Ak = A((index-1)*obj.num_history_days+1 : index*obj.num_history_days);
                plot(Ak);
                index2 = index + 1;
                Ak = A((index2-1)*obj.num_history_days+1 : index2*obj.num_history_days);
                plot(Ak);
                title('Coefficients of precipitation influence by number of days in the past');
                legend(legends, 'Location', 'southwest');
                ylim([-0.05,0.05]);
                
                hline = refline([0 0]);
                hline.Color = 'r';
                hold off;
            end
      
        end
        
        function predict_fdom_metabasins_single(obj, basin)
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
            totals = obj.metabasin_precipitation_totals.sums{basin}.getArray;
            totals = double(totals);
            dates = obj.metabasin_precipitation_totals.timestamps{basin}.getArray;
            dates = char(dates);
            timestamps = datenum(dates,'yyyymmdd');
            %x_maps is a vector so this is a problem
            map = java.util.Hashtable;
            size(totals, 1)
            for i = 1:size(totals, 1)
                map.put(timestamps(i), totals(i));
            end
            % map
            
            obj.predicted_values = zeros(sample_count);
            
            for i=1:sample_count(1)
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                
                
                precip_totals = zeros(obj.num_history_days, 1);
                for j = 1:obj.num_history_days
                    d = datenum(date - days(j));
                    precip_totals(j) = 0;
                    
                    if map.containsKey(d)
                        precip_totals(j) = map.get(d);
                    end
                    
                end
                
                % add up the predictor variables
                for j = 1:obj.num_history_days
                    obj.predicted_values(i) = obj.predicted_values(i) + obj.a((basin-1) * obj.num_history_days +  j + 1) * precip_totals(j);
                end
                
                
                if( str2double(datestr(date, 'mm')) > 9)
                    obj.predicted_values(i) = obj.predicted_values(i) +  obj.a((basin-1) * obj.num_history_days + 2);
                end
            end
        end
        
        function single_basin_compare(obj)
            figure;
            hold on;
            plot(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom);
            for i=1:6
                predict_fdom_metabasins_single(obj, i);
                plot(obj.usgs_timeseries_subset_timestamps, obj.predicted_values);
                
                title('Modeled and Sensor FDOM');
            end
            hold off;
        end
        
        function precipitation_running_average(obj)
           precipitation_running_avg = zeros(length(obj.precipitation_timestamps),1);
           len = length(precipitation_running_avg);
           window = 90;
           half_window = floor(window/2);
           for i = half_window+1:len-half_window-1
              sum = 0;
              for j = 1:window
                 sum = sum + obj.precipitation_data.total_precipitation(i - half_window + j);
              end
              precipitation_running_avg(i) = sum;
           end
           figure;
           plot(obj.precipitation_timestamps, precipitation_running_avg);
           datetick('x');
        end
    end
    
end

