classdef haddam_fdom < handle
    
    properties
        % configuration
        seasonal_mode = 3; % modeled | step | 12 month, constants below
        enable_y_intercept = true;
        
        % constants
        seasonal_mode_none = 0;
        seasonal_mode_step = 1;
        seasonal_mode_modeled = 2;
        seasonal_mode_12_month = 3;
        seasonal_mode_insolation = 4;
        
        % vars
        conn;
        usgs_timeseries;
        usgs_timeseries_timestamps;
        usgs_timeseries_filtered_discharge;
        usgs_timeseries_filtered_doc_mass_flow;
        usgs_timeseries_filtered_doc_concentration;
        usgs_timeseries_filtered_doc_mass_flow_eq2;
        usgs_timeseries_filtered_doc_concentration_eq2;
        
        fdom_corrected;
        fdom_corrected_timestamps;
        precipitation_data;
        precipitation_timestamps;
        precipitation_map;
        enable_precip_bins = false;
        bin_sizes = [60,60,60];
        num_bins = 3;
        
        usgs_daily_means;
        usgs_daily_means_timestampes;
        
        seasonal_doc_julian;
        
        start_date = '2012-01-01';
        end_date = '2016-01-01';
        parameterization_start_date = '2012-01-01';
        parameterization_end_date = '2016-01-01';
        
        event_start_dates = [];
        event_end_dates = [];
        event_total_sizes = [];
        
        metabasin_precipitation_totals;
        
        usgs_timeseries_subset;
        usgs_timeseries_subset_timestamps;
        
        insolation;
        
        % inverse modeling
        num_history_days = 14;
        K;
        y;
        a;
        predicted_values;
        
        predictions;
        
        precipitation_running_avg;
        
        snow_melt;
        snow_melt_timestamps;
        snow_map;
        enable_snow = false;
        snow_date_offset = 4; % initial delay for snow in days
        num_snow_history = 0;
        
        enable_snow_bins = false;
        snow_bin_sizes = [10];
        num_snow_bins = 1;
        
        pdsi;
       
        % stats
        F_series;
        R_sqr_series;
        RSS_series;
        
    end
    
    methods(Static)
                
        function [dayOfYear] = day_of_year(in_date_num)
            prevYear = datenum(year(datetime(in_date_num, 'ConvertFrom', 'datenum'))-1, 12,31);
            dayOfYear = in_date_num-prevYear;
            if (dayOfYear == 366)
                dayOfYear = 365;
            end
        end
        
        
        function [hf] = start()
            hf = haddam_fdom();
            disp 'opening connection'
            hf.open_connection();
            %disp 'loading usgs timeseries'
            %hf.load_usgs_timeseries();
            %disp 'loading fdom corrected'
            %hf.load_fdom_corrected();
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
            sqlquery = sprintf(['select timestamp,cdom,discharge,doc_mass_flow,doc_mass_flow_eq2,doc_concentration,doc_concentration_eq2,doxygen,nitrate,conductance,turbidity,ph,temperature,month from haddam_timeseries_usgs_extended '...
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
        
        function load_usgs_timeseries_cdom_2012_2015(obj)
            sqlquery = sprintf(['select timestamp,cdom,discharge,doc_mass_flow from haddam_timeseries_usgs '...
                'where cdom > 0 and ' ...
                'timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp < to_timestamp(''%s'', ''YYYY-MM-DD'') '...
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
            sqlquery = sprintf(['select timestamp,cdom,discharge,ph,doc_mass_flow from haddam_timeseries_usgs_extended '...
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
        
        function load_usgs_daily_means(obj, mode)
            
             if mode == 1 % skip fouled data
                 
               sqlquery = sprintf(['select timestamp,cdom,discharge,doc_mass_flow,temp,turbidity from haddam_download_usgs '...
                    'where cdom > 0 ' ...
                    'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                    'AND ( timestamp <= to_timestamp(''2013-07-10'', ''YYYY-MM-DD'') OR timestamp >= to_timestamp(''2013-09-10'', ''YYYY-MM-DD'') )'...
                    'order by timestamp asc'], obj.start_date, obj.end_date);
             elseif mode == 2 % skip fouled data and spring freshet
                 sqlquery = sprintf(['select timestamp,cdom,discharge,doc_mass_flow from haddam_download_usgs '...
                    'where cdom > 0 ' ...
                    'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                    'AND ( timestamp <= to_timestamp(''2013-07-10'', ''YYYY-MM-DD'') OR timestamp >= to_timestamp(''2013-09-10'', ''YYYY-MM-DD'') )'...
                    'AND ( month < 4 OR month > 5 )'...
                    'order by timestamp asc'], obj.start_date, obj.end_date);
             else
            
                sqlquery = sprintf(['select timestamp,cdom,discharge,doc_mass_flow from haddam_download_usgs '...
                    'where cdom > 0 ' ...
                    'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                    'order by timestamp asc'], obj.start_date, obj.end_date);
                                % 'and month > 5 ' ...
             end
                            
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_daily_means = curs.Data;
            obj.usgs_daily_means_timestampes = datenum(obj.usgs_daily_means.timestamp);
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
        
         function filter_doc_mass_flow_eq2(obj)
            lpFilt = designfilt('lowpassiir', 'FilterOrder', 1, 'StopbandFrequency', .999, 'StopbandAttenuation', 100);
            fvtool(lpFilt);
            
            
            dataIn = obj.usgs_timeseries.doc_mass_flow_eq2;
            % deal with empty data
            tf = isnan(dataIn);
            ix = 1:numel(dataIn);
            dataIn(tf) = interp1(ix(~tf),dataIn(~tf),ix(tf));
            
            %dataIn = rand([400 1]); dataOut = filter(lpFilt,dataIn);
            %dataIn = obj.usgs_timeseries.discharge;
            dataOut = filtfilt(lpFilt,dataIn);
            plot(dataOut);
            plot([dataIn, dataOut]);
            
            obj.usgs_timeseries_filtered_doc_mass_flow_eq2 = dataOut;
        end
        
        function filter_doc_concentration(obj)
            lpFilt = designfilt('lowpassiir', 'FilterOrder', 1, 'StopbandFrequency', .999, 'StopbandAttenuation', 100);
            fvtool(lpFilt);
            
            
            dataIn = obj.usgs_timeseries.doc_concentration;
            % deal with empty data
            tf = isnan(dataIn);
            ix = 1:numel(dataIn);
            dataIn(tf) = interp1(ix(~tf),dataIn(~tf),ix(tf));
            
            %dataIn = rand([400 1]); dataOut = filter(lpFilt,dataIn);
            %dataIn = obj.usgs_timeseries.discharge;
            dataOut = filtfilt(lpFilt,dataIn);
            plot(dataOut);
            plot([dataIn, dataOut]);
            
            obj.usgs_timeseries_filtered_doc_concentration = dataOut;
        end
        
        function filter_doc_concentration_eq2(obj)
            lpFilt = designfilt('lowpassiir', 'FilterOrder', 1, 'StopbandFrequency', .999, 'StopbandAttenuation', 100);
            fvtool(lpFilt);
            
            
            dataIn = obj.usgs_timeseries.doc_concentration_eq2;
            % deal with empty data
            tf = isnan(dataIn);
            ix = 1:numel(dataIn);
            dataIn(tf) = interp1(ix(~tf),dataIn(~tf),ix(tf));
            
            %dataIn = rand([400 1]); dataOut = filter(lpFilt,dataIn);
            %dataIn = obj.usgs_timeseries.discharge;
            dataOut = filtfilt(lpFilt,dataIn);
            plot(dataOut);
            plot([dataIn, dataOut]);
            
            obj.usgs_timeseries_filtered_doc_concentration_eq2 = dataOut;
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
            obj.start_date = '2009-01-01';
            obj.end_date = '2016-01-01';
            sqlquery = sprintf(['select total_precipitation, timestamp from total_macrowatershed_precipitation ' ...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') order by timestamp'], ...
                obj.start_date, obj.end_date);
            sqlquery
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.precipitation_data = curs.Data;
            obj.precipitation_timestamps = datenum(obj.precipitation_data.timestamp)
               % organize the precipitation for lookup
               
             % make it stationary
            %p1 = obj.precipitation_data.total_precipitation;
            %p2 = obj.precipitation_data.total_precipitation;
            %p2(1) = [];
            %p1(end) = [];
            %p = p2 - p1;
            %obj.precipitation_timestamps(1) = [];
            %obj.precipitation_data.total_precipitation = (p / max(p) );
            % this way of making the data stationary does not work
            % because we need the 0 values to make this model make sense
            % or else the FDOM signal also must be stationarized
            obj.precipitation_map = containers.Map(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
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
        
         function plot_precipitation_vs_filtered_doc_mass_flow(obj)

            figure
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_doc_mass_flow, ...
               obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            legend('DOC Mass Flow', 'Total Precipitation');
            
            
            figure
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_doc_mass_flow, ...
               obj.precipitation_timestamps, obj.precipitation_running_avg);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            legend('DOC Mass Flow', 'Precipitation 1 Month Running Average');

         end
         
            
        function find_precipitation_events(obj, opt1, opt2)
            if(nargin > 1)
                event_start_threshold = opt1;
                event_end_threshold = opt2;
            else
                event_start_threshold = 900;
                event_end_threshold = 900;
            end
            
            % process for events
            in_event = false;
            event_start_date = 0;
            event_end_date = 0;
            event_total_size = 0;
            
            obj.event_start_dates = [];
            obj.event_end_dates = [];
            obj.event_total_sizes = [];
            
            for i=1:length(obj.precipitation_data.total_precipitation)
                precipitation = obj.precipitation_data.total_precipitation(i);
                
                if in_event == false
                    if precipitation > event_start_threshold
                        in_event = true;
                        event_start_date = obj.precipitation_timestamps(i);
                        event_total_size = precipitation;
                    end
                else
                    if precipitation > event_end_threshold
                        event_total_size = event_total_size + precipitation
                    else precipitation < event_end_threshold
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
            datetick(hax(1));
            datetick(hax(2));
            %hLine1.LineStyle = '+';
            %hLine2.LineStyle = '-o';
            
            
            
        end
        
        function plot_event_lenghts(obj)
            figure; plot(hf.event_start_dates, event_lengths, 'o'); ylim([0 5])
        end
        
        function [begin, ends] = find_mass_flow_rising(obj)
            
           begin = zeros(length(obj.event_start_dates), 1);
           for i = 1:length(obj.event_start_dates)
               
               start_index = find(obj.usgs_timeseries_timestamps == obj.event_start_dates(i),1);
               if isempty(start_index)
                    continue;
               end
                   
               for j = 0:24*3*4   % only search 3 days forward, should be more than enough
                  rise = (obj.usgs_timeseries_filtered_doc_mass_flow_eq2(start_index+j+1) - obj.usgs_timeseries_filtered_doc_mass_flow_eq2(start_index+j));
                  if rise >= .7
                      begin(i) = obj.usgs_timeseries_timestamps(start_index+j);
                      break;
                  end
               end
           end
           begin(begin == 0) = [];
           
           % and find ends
           ends = zeros(length(begin), 1);
           for i = 1:length(begin)
               start_index = find(obj.usgs_timeseries_timestamps == begin(i),1);
               for j = 0:24*3*4   % only search 3 days forward, should be more than enough
                  rise = (obj.usgs_timeseries_filtered_doc_mass_flow_eq2(start_index+j+1) - obj.usgs_timeseries_filtered_doc_mass_flow_eq2(start_index+j));
                  if rise >= -.7
                      % check curvature
                      % should be becomming less negative at end of falling
                      % limb
                      previous_rise = (obj.usgs_timeseries_filtered_doc_mass_flow_eq2(start_index+j) - obj.usgs_timeseries_filtered_doc_mass_flow_eq2(start_index+j-1));
                      if(rise > previous_rise)
                          ends(i) = obj.usgs_timeseries_timestamps(start_index+j);
                      end
                  end
               end
           end
           
             % events and FDOM
            figure;
            hold on;
            stem(begin, ones(length(begin),1)*500);
            stem(obj.event_start_dates, obj.event_total_sizes);
            datetick('x');
            hold off;

            %[hax, hLine1, hLine2] = plotyy(begin, ones(length(begin),1), obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_doc_mass_flow_eq2, 'stem', 'plot');

            figure;
            subplot(2,1,1)
            [hax, hLine1, hLine2] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, obj.event_start_dates, obj.event_total_sizes, 'plot', 'stem');
            datetick(hax(1), 'keeplimits');
            datetick(hax(2), 'keeplimits');
            set(hax(1),'XLim',[min(obj.event_start_dates) max(obj.usgs_timeseries_timestamps)])
            set(hax(2),'XLim',[min(obj.event_start_dates) max(obj.usgs_timeseries_timestamps)])
            
            subplot(2,1,2)
            [hax, hLine1, hLine2] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries_filtered_discharge, begin, ones(length(begin),1), 'plot', 'stem');
            datetick(hax(1), 'keeplimits');
            datetick(hax(2), 'keeplimits');
            set(hax(1),'XLim',[min(obj.event_start_dates) max(obj.usgs_timeseries_timestamps)])
            set(hax(2),'XLim',[min(obj.event_start_dates) max(obj.usgs_timeseries_timestamps)])
        end
        
        function plot_events_and_cdom(obj)
            % events and FDOM
            figure;
            [hax, hLine1, hLine2] = plotyy(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, obj.event_start_dates, obj.event_total_sizes, 'plot', 'stem');
            %set(hLine1,'color','red');
            %set(hLine2,'color','blue');
            datetick(hax(1), 'keeplimits');
            datetick(hax(2), 'keeplimits');
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Precipitation Events and FDOM');
            labels = cellstr( num2str([1:length(obj.event_start_dates)]') ); 
            text(obj.event_start_dates, obj.event_total_sizes, labels, 'parent', hax(2)); %,
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
            labels = cellstr( num2str([1:length(obj.event_start_dates)]') ); 
            text(obj.event_start_dates, obj.event_total_sizes, labels, 'parent', hax(2)); %, ...
                                             %'HorizontalAlignment','right');

                             %'VerticalAlignment','bottom', ...
            
          
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
        
        function load_insolation(obj)
            insolation_data = csvread('../Insolation.csv')
            obj.insolation = insolation_data(:,3);
        end
        
        function load_snowmelt(obj)
            snow_melt_data = csvread('/Users/matthewxi/Documents/Projects/PrecipGeoStats/snow/snow_scatch.txt');
            obj.snow_melt = snow_melt_data(:,2) / 1000 ;  % divide to avoid precision issues            
            %obj.snow_melt = sqrt(snow_melt_data(:,2)) ; 
            %obj.snow_melt = nthroot(snow_melt_data(:,2),4); 

            obj.snow_melt_timestamps = datenum(num2str(snow_melt_data(:,1)), 'yyyymmdd');
            obj.snow_map = containers.Map(obj.snow_melt_timestamps, obj.snow_melt );
        end
        
        function load_pdsi(obj)
           pdsi = csvread('/Users/matthewxi/Documents/Projects/PrecipGeoStats/PDSI/hrap_jacobi/Palmer.matlab.txt');
           obj.pdsi = pdsi(:,10); 
           
        end
        
        function build_predictor_matrix(obj, timestamps)
            
            % y = a3 * p3 + a4 * p4 + a5 * p5 + c
            % pi is precipitation total i days ago
            
            sample_count = size(timestamps);
            sample_count = sample_count(1);
            %sample_count = 10;
            obj.K = zeros(sample_count, obj.num_history_days + obj.enable_y_intercept);  % should size based off seasonal mode
            
            for i=1:sample_count
                date = timestamps(i);
                
                precip_totals = zeros(obj.num_history_days, 1);
                for j = 2:obj.num_history_days+1
                    if(j == 1)
                        d = date;  % start with the current day
                    else
                        d = date - (j-1);
                    end
                   
                    precip_totals(j-1) = 0;
                    if isKey(obj.precipitation_map, d)
                        precip_totals(j-1) = obj.precipitation_map(d);
                    end
                end
                
                offset = 0;
                if(obj.enable_y_intercept)
                    offset = offset + 1;
                    obj.K(i, 1) = 1;  
                end
                
                if(obj.enable_snow)
                   for s = 0:obj.num_snow_history - 1
                    offset = offset + 1;
                    snow_date = date - obj.snow_date_offset - s;
                     if isKey(obj.snow_map, snow_date)
                        obj.K(i, offset) = obj.snow_map(snow_date);
                    end
                   end
                end
                
                if(obj.enable_precip_bins)
                    for bin = 1:obj.num_bins
                      offset = offset + 1;
                      binned_precip = 0;
                      previos_bin_offset = sum(obj.bin_sizes(1:bin-1));
                      for l = 1:obj.bin_sizes(bin)
                        d = date - obj.num_history_days - previos_bin_offset - l;
                             if isKey(obj.precipitation_map, d)
                                 binned_precip = binned_precip+ obj.precipitation_map(d);
                              end
                      end
                      obj.K(i, offset) = binned_precip;
                    end
                end
                
               if(obj.enable_snow_bins)
                    for bin = 1:obj.num_snow_bins
                      offset = offset + 1;
                      binned_snow= 0;
                      previos_bin_offset = sum(obj.snow_bin_sizes(1:bin-1));
                      for l = 1:obj.snow_bin_sizes(bin)
                        d = date - obj.num_snow_history - previos_bin_offset - l;
                             if isKey(obj.snow_map, d)
                                 binned_snow = binned_snow + obj.snow_map(d);
                              end
                      end
                      obj.K(i, offset) = binned_snow;
                    end
                end
                
                
                for j = 1:obj.num_history_days
                    obj.K(i, j+offset) = precip_totals(j);
                end
                
                d = str2double(datestr(date, 'dd'));
                
                %
                % seasonal effect - autumn
                %
                
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                        obj.K(i, obj.num_history_days+offset+1) = 1;
                    else
                        obj.K(i, obj.num_history_days+offset+1) = 0;hf.s
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    haddam_fdom.day_of_year(date);
                    obj.K(i, obj.num_history_days+offset+1) = obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;  % multiply by 10000 to avoid matrix precision problems
                
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    thismonth = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = obj.num_history_days+offset+(m + 1 - start_month);
                        if(m == thismonth)
                           obj.K(i, index) = 1; 
                        else
                           obj.K(i, index) = 0;
                        end
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_insolation)
                    m = month(date);
                    obj.K(i, obj.num_history_days+offset+1) = obj.insolation(m);  % multiply by ? to avoid matrix precision problems
                    %obj.K(i, obj.num_history_days+2) = 1;
                end
                
              
            end
            
            %obj.K
            
        end
        
        function solve_inverse(obj)
            %obj.K
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
            
            % obj.predicted_values = obj.z * obj.K
           
            % so this should just be obj.a * obj.K
            
            obj.predicted_values = zeros(sample_count);
            
            for i=1:sample_count(1)
                date = timestamps(i);
                
                precip_totals = zeros(obj.num_history_days, 1);
                for j = 1:obj.num_history_days
                    if(j==1)
                        d = date;
                    else
                        d = date - (j-1);
                    end
                    precip_totals(j) = 0;
                    if isKey(obj.precipitation_map, d)
                        precip_totals(j) = obj.precipitation_map(d);
                    end
                end
                
                
                offset = 0;
                if(obj.enable_y_intercept)
                    offset = 1;
                    obj.predicted_values(i) = obj.a(1);
                end
                
                if(obj.enable_snow)
                   for s = 0:obj.num_snow_history - 1
                       offset = offset + 1;
                       snow_date = date - obj.snow_date_offset - s;
                       if isKey(obj.snow_map, snow_date)
                         obj.predicted_values(i) = obj.predicted_values(i) + obj.a(offset) *  obj.snow_map(snow_date);
                       end
                   end
                end
                
                 if(obj.enable_precip_bins)
                    for bin = 1:obj.num_bins
                        offset = offset + 1;
                        binned_precip = 0;
                        previos_bin_offset = sum(obj.bin_sizes(1:bin-1));
                        for l = 1:obj.bin_sizes(bin)
                            d = date - obj.num_history_days - previos_bin_offset - l;
                            if isKey(obj.precipitation_map, d)
                                binned_precip = binned_precip + obj.precipitation_map(d);
                            end
                        end
                        obj.predicted_values(i) = obj.predicted_values(i) + obj.a(offset) *  binned_precip;
                    end
                 end
                
                  if(obj.enable_snow_bins)
                    for bin = 1:obj.num_snow_bins
                        offset = offset + 1;
                        binned_snow = 0;
                        previos_bin_offset = sum(obj.snow_bin_sizes(1:bin-1));
                        for l = 1:obj.snow_bin_sizes(bin)
                            d = date - obj.num_snow_history - previos_bin_offset - l;
                            if isKey(obj.snow_map, d)
                                binned_snow = binned_snow + obj.snow_map(d);
                            end
                        end
                        obj.predicted_values(i) = obj.predicted_values(i) + obj.a(offset) *  binned_snow;
                    end
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
                    thismonth = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = j + offset + (m + 1 - start_month);
                        if(m == thismonth)
                           obj.predicted_values(i) = obj.predicted_vnalues(i) + obj.a(index);
                        end
                    end
                    
                elseif(obj.seasonal_mode == obj.seasonal_mode_insolation)
                    m = month(date);
                    obj.predicted_values(i) = obj.predicted_values(i) + obj.a(obj.num_history_days + offset + 1) * obj.insolation(m); 
                    %obj.predicted_values(i) = obj.predicted_values(i) + obj.a(obj.num_history_days + offset + 2)
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
        
       function inverse_model_cdom(obj, mode)
           obj.enable_y_intercept = true;
           obj.num_bins = 0;
           obj.bin_sizes = [20];
           obj.seasonal_mode = obj.seasonal_mode_insolation;
           if mode == 4
               obj.seasonal_mode = obj.seasonal_mode_none;
               mode = 1;
           end
           
           obj.load_values_cdom(mode);
           obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
           obj.solve_inverse;
           obj.predict(obj.usgs_daily_means_timestampes);
           obj.plot_prediction(obj.usgs_daily_means.cdom, obj.predicted_values, obj.usgs_daily_means_timestampes);
           rsquare(obj.usgs_daily_means.cdom, obj.predicted_values)
       end
       
        function inverse_model_cdom_stationarized(obj, mode)
           obj.enable_y_intercept = true;
           obj.num_bins = 0;
           obj.bin_sizes = [20];
           obj.seasonal_mode = obj.seasonal_mode_insolation;
           if mode == 4
               obj.seasonal_mode = obj.seasonal_mode_none;
               mode = 1;
           end
           
           obj.load_values_cdom(mode);
           obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
           obj.solve_inverse;
           obj.predict(obj.usgs_daily_means_timestampes(2:end));
           
           cdom1 = obj.usgs_daily_means.cdom(1:end-1);
           cdom2 = obj.usgs_daily_means.cdom(2:end);
           cdom = cdom2-cdom1;
           
           obj.plot_prediction_st(cdom, obj.predicted_values, obj.usgs_daily_means_timestampes(2:end));
           rsquare(obj.usgs_daily_means.cdom, obj.predicted_values)
       end
        
       function iterative_nested_cdom(obj)
          obj.parameterization_start_date = '2012-01-01';
          obj.parameterization_end_date = '2015-01-01';

          obj.num_history_days = 0;
          obj.inverse_model_cdom(1);
          RSS_nested = sum((obj.usgs_daily_means.cdom - obj.predicted_values).^2);
          degrees_of_freedom_nested = length(obj.a);
          data_size = length(obj.K);

          
          max_history_days = 20;
          obj.F_series = zeros(max_history_days,1);
          obj.R_sqr_series = zeros(max_history_days,1);
          obj.RSS_series = zeros(max_history_days + 1,1);
          obj.RSS_series(1) = RSS_nested;
          for i = 1:max_history_days
              obj.num_history_days = i
              obj.inverse_model_cdom(1);
              RSS_2 = sum((obj.usgs_daily_means.cdom - obj.predicted_values).^2);
              degrees_of_freedom_2 =  length(obj.a);
              
              F = ( (RSS_nested - RSS_2) / (degrees_of_freedom_2 - degrees_of_freedom_nested) ) /  (RSS_2 / ( data_size - degrees_of_freedom_2));
              obj.F_series(i) = F;
              obj.R_sqr_series(i) = rsquare(obj.usgs_daily_means.cdom, obj.predicted_values);
              
              obj.RSS_series(i+1) = RSS_2;
              RSS_nested = RSS_2;
              
          end
          obj.F_series
          obj.R_sqr_series
          
          figure;
          plot(obj.F_series)
          line([0, 20], [6.6, 6.6])
       end
       
       function iterative_nested_mass_flow(obj)
          obj.enable_precip_bins = false;
           
          obj.parameterization_start_date = '2012-01-01';
          obj.parameterization_end_date = '2015-01-01';

          obj.num_history_days = 0;
          obj.inverse_model_mass_flow;
          nanIdx = isnan(obj.usgs_daily_means.doc_mass_flow);
          observed = obj.usgs_daily_means.doc_mass_flow;
          observed(nanIdx) = [];
          predicted = obj.predicted_values;
          predicted(nanIdx) = [];
          RSS_nested = sum((observed- predicted).^2);
          degrees_of_freedom_nested = length(obj.a);
          data_size = length(obj.K);

          
          max_history_days = 10;
          obj.F_series = zeros(max_history_days,1);
          obj.R_sqr_series = zeros(max_history_days,1);
          obj.RSS_series = zeros(max_history_days + 1,1);
          obj.RSS_series(1) = RSS_nested;
          for i = 1:max_history_days
              obj.num_history_days = i
              obj.inverse_model_mass_flow;
              predicted = obj.predicted_values;
              predicted(nanIdx) = [];
              RSS_2 = sum((observed - predicted).^2);
              degrees_of_freedom_2 =  length(obj.a);
              
              F = ( (RSS_nested - RSS_2) / (degrees_of_freedom_2 - degrees_of_freedom_nested) ) /  (RSS_2 / ( data_size - degrees_of_freedom_2));
              obj.F_series(i) = F;
              obj.R_sqr_series(i) = rsquare(observed, predicted);
              
              obj.RSS_series(i+1) = RSS_2;
              RSS_nested = RSS_2;
              
          end
          obj.F_series
          obj.R_sqr_series
          
          figure;
          plot(obj.F_series)
          line([0, 20], [6.6, 6.6])
          line([0, 20], [3.85, 3.85])
       end
       
       function nested_precip_bins(obj)
          obj.parameterization_start_date = '2012-01-01';
          obj.parameterization_end_date = '2015-01-01';

          obj.num_history_days = 0;
          obj.enable_precip_bins = false;
          obj.inverse_model_cdom(1);
          RSS_nested = sum((obj.usgs_daily_means.cdom - obj.predicted_values).^2);
          degrees_of_freedom_nested = length(obj.a);
          data_size = length(obj.K);

       

          obj.R_sqr_series = zeros(obj.num_bins+1,1);
          obj.R_sqr_series(1) = rsquare(obj.usgs_daily_means.cdom, obj.predicted_values);
          obj.F_series = zeros(obj.num_bins,1);
          obj.RSS_series = zeros(max_bins + 1,1);
          obj.RSS_series(1) = RSS_nested;
          
          max_bins = 1;
          obj.num_history_days = 11;
          obj.enable_precip_bins = true;
          for i = 1:max_bins
              obj.num_bins = i;
              obj.inverse_model_cdom(1);
              RSS_2 = sum((obj.usgs_daily_means.cdom - obj.predicted_values).^2);
              degrees_of_freedom_2 =  length(obj.a);
              
              F = ( (RSS_nested - RSS_2) / (degrees_of_freedom_2 - degrees_of_freedom_nested) ) /  (RSS_2 / ( data_size - degrees_of_freedom_2));
              obj.F_series(i) = F;
              obj.R_sqr_series(i+1) = rsquare(obj.usgs_daily_means.cdom, obj.predicted_values);
              
              obj.RSS_series(i+1) = RSS_2;
              RSS_nested = RSS_2;
              
          end
          obj.F_series
          obj.R_sqr_series
          
          figure;
          plot(obj.F_series)
          line([0, 20], [6.6, 6.6])
          
       end
       
       function nested_precip_bins_mass_flow(obj)
          obj.parameterization_start_date = '2012-01-01';
          obj.parameterization_end_date = '2015-01-01';

          obj.num_history_days = 8;
          obj.enable_precip_bins = false;
          obj.inverse_model_mass_flow;
          nanIdx = isnan(obj.usgs_daily_means.doc_mass_flow);
          observed = obj.usgs_daily_means.doc_mass_flow;
          observed(nanIdx) = [];
          predicted = obj.predicted_values;
          predicted(nanIdx) = [];
          RSS_nested = sum((observed-predicted).^2);
          degrees_of_freedom_nested = length(obj.a);
          data_size = length(obj.K);

          max_bins = 3;

          obj.R_sqr_series = zeros(max_bins+1,1);
          obj.R_sqr_series(1) = rsquare(observed, predicted);
          obj.F_series = zeros(max_bins,1);
          obj.RSS_series = zeros(max_bins + 1,1);
          obj.RSS_series(1) = RSS_nested;
          
          obj.enable_precip_bins = true;
          for i = 1:max_bins
              obj.num_bins = i;
              obj.inverse_model_mass_flow;
              predicted = obj.predicted_values;
              predicted(nanIdx) = [];
              RSS_2 = sum((observed-predicted).^2);
              degrees_of_freedom_2 =  length(obj.a);
              
              F = ( (RSS_nested - RSS_2) / (degrees_of_freedom_2 - degrees_of_freedom_nested) ) /  (RSS_2 / ( data_size - degrees_of_freedom_2));
              obj.F_series(i) = F;
              obj.R_sqr_series(i+1) = rsquare(observed, predicted);
              
              obj.RSS_series(i+1) = RSS_2;
              RSS_nested = RSS_2;
              
          end
          obj.F_series
          obj.R_sqr_series
          
          figure;
          plot(obj.F_series)
          line([0, 20], [6.6, 6.6])
          line([0, 20], [3.85, 3.85])

       end
       
       
       function inverse_model_mass_flow(obj)
           obj.enable_y_intercept = true;
           obj.enable_snow = true;
           obj.seasonal_mode = obj.seasonal_mode_insolation;
           obj.load_values('doc_mass_flow');
           
           obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
           
           obj.solve_inverse;
           
           % get entire timeseries
           
           obj.predict(obj.usgs_daily_means_timestampes);
           obj.plot_prediction(obj.usgs_daily_means.doc_mass_flow, obj.predicted_values, obj.usgs_daily_means_timestampes);
           rsquare(obj.usgs_daily_means.doc_mass_flow, obj.predicted_values)
       end
          
       function inverse_model_conductance(obj)
           obj.seasonal_mode = obj.seasonal_mode_12_month;
           obj.build_inversion('conductance_mean');
           obj.solve_inverse
           obj.predict(obj.usgs_timeseries_subset_timestamps);
           obj.plot_prediction(  obj.usgs_timeseries_subset.value );
       end
        
        function inverse_model_discharge(obj)
           obj.seasonal_mode = obj.seasonal_mode_none;
           obj.build_inversion('discharge_tidally_filtered');
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
        
        
        function debug(obj)
            s_date = obj.parameterization_start_date;
            e_date = obj.parameterization_end_date;
            field = 'cdom';
            sqlquery = sprintf(['select timestamp, %s as value from haddam_download_usgs '...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], field, s_date, e_date);
                            % 'and month > 5 ' ...
                            %                 'and value > 0 ' ...


       
            figure;
            hold on;
            
            plot(obj.usgs_timeseries_timestamps, obj.usgs_timeseries.cdom, 'x');

            
            sqlquery = sprintf(['select timestamp, cdom as value from haddam_download_usgs where cdom > 0 order by timestamp asc '], field);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            
            plot(datenum(curs.Data.timestamp),curs.Data.value, 'o');
            datetick('x', 3);
            
            
            sqlquery = sprintf(['select timestamp, cdom as value from haddam_download_usgs order by timestamp asc '], field);
            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            
            plot(datenum(curs.Data.timestamp),curs.Data.value, '-');
            datetick('x', 3);
            
            
        end
        
        function load_values(obj, field)
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
            obj.y =  obj.usgs_timeseries_subset.value;

     
            % should do interp, not set to zero
            % obj.y(isnan(obj.y))=0;
            % obj.y = fixgaps(obj.y);
            nanIndicies = isnan(obj.y);
            obj.y(nanIndicies) = [];
            obj.usgs_timeseries_subset_timestamps(nanIndicies) = [];
        end
        
         function load_values_cdom(obj, mode)
            field = 'cdom';
            s_date = obj.parameterization_start_date;
            e_date = obj.parameterization_end_date;
            
            % may want to specify different parameterization date range
            % from prediction range
            %s_date = '2012-01-01';
            %e_date = '2012-02-01';
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            if mode == 1 % skip fouled data
                sqlquery = sprintf(['select timestamp, %s as value from haddam_download_usgs '...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'AND ( timestamp <= to_timestamp(''2013-07-10'', ''YYYY-MM-DD'') OR timestamp >= to_timestamp(''2013-09-10'', ''YYYY-MM-DD'') )'...
                'order by timestamp asc'], field, s_date, e_date);
            elseif mode == 2 % everything
                sqlquery = sprintf(['select timestamp, %s as value from haddam_download_usgs '...
                'where timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], field, s_date, e_date);
            elseif mode == 3  % skip early months and fouling
                sqlquery = sprintf(['select timestamp, %s as value from haddam_download_usgs '...
                'where month > 5 AND timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'AND ( timestamp <= to_timestamp(''2013-07-01'', ''YYYY-MM-DD'') OR timestamp >= to_timestamp(''2013-09-01'', ''YYYY-MM-DD'') )'...
                'order by timestamp asc'], field, s_date, e_date);
            end

            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.timestamp);
            obj.y = obj.usgs_timeseries_subset.value;

            % stationarize this..
            % y1 = obj.y;
            % y2 = obj.y;
            % y1(end) = [];
            % y2(1) = [];
            % obj.y = y2 - y1;
            % obj.usgs_timeseries_subset_timestamps(1) = [];
     
            % should do interp, not set to zero
            % or just remove entirely might be a better approach
            % obj.y(isnan(obj.y))=0;
            obj.y = fixgaps(obj.y);
            nanIndicies = isnan(obj.y);
            obj.y(nanIndicies) = [];
            obj.usgs_timeseries_subset_timestamps(nanIndicies) = [];
     
            if strcmp(field, 'cdom')
                % do some preprocessing
                % what is the meaning of this exactly ??
                %obj.y(obj.y < 17) = 17;
            end
             
         end
        
         
          function load_values_timeseries_avg(obj, field)
            s_date = obj.parameterization_start_date;
            e_date = obj.parameterization_end_date;
            
            % always skipping the fouling period
            
            sqlquery = sprintf(['select date, %s as value from haddam_timeseries_daily_avg '...
                'where date >= to_timestamp(''%s'', ''YYYY-MM-DD'') and date <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'AND ( timestamp <= to_timestamp(''2013-07-10'', ''YYYY-MM-DD'') OR timestamp >= to_timestamp(''2013-09-10'', ''YYYY-MM-DD'') )'...
                'and %s > 0 ' ...
                'order by date asc'], field, s_date, e_date, field);
                     


            disp(sqlquery);
            curs = exec(obj.conn,sqlquery);
            setdbprefs('DataReturnFormat','structure');
            curs = fetch(curs);
            obj.usgs_timeseries_subset = curs.Data;
            obj.usgs_timeseries_subset_timestamps = datenum(obj.usgs_timeseries_subset.date, 'yyyy-mm-dd');
            obj.y =  obj.usgs_timeseries_subset.value;

     
            % should do interp, not set to zero
            % actually interp could be cheating...  because it's not really
            % the original observations
            % obj.y(isnan(obj.y))=0;
            % obj.y = fixgaps(obj.y);
            nanIndicies = isnan(obj.y);
            obj.y(nanIndicies) = [];
            obj.usgs_timeseries_subset_timestamps(nanIndicies) = [];
        end
        
       function build_inversion(obj, field)
            obj.load_values(field)
           
            disp('Building Predictor Matrix');
            obj.build_predictor_matrix(obj.usgs_timeseries_subset_timestamps);
            disp('Built Predictor Matrix');
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
        
        function plot_residuals(obj, observed)
             plot(obj.usgs_timeseries_subset_timestamps, observed - obj.predicted_values);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            %ylim([0,max_observed]);
            title('Residuals');
        end
        
        function plot_prediction(obj, observed, prediction, timestamps)
            figure();
            max_observed = max(observed);
            %max_observed = 100;
            
            subplot(4,1,1);
            plot(timestamps, observed - prediction);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            ylim([-max_observed,max_observed]);
            title('Residuals');
            
            subplot(4,1,2);
            plot(timestamps, observed, 'o', 'MarkerSize',1);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            ylim([0,max_observed]);
            title('Observed Values');
            
            
            subplot(4,1,3);
            plot(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            title('Precipitation');
            
            subplot(4,1,4);
            [hax, ~, ~] = plotyy(timestamps, observed, ...
                timestamps, prediction);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 max_observed])
            set(hax(2),'YLim',[0 max_observed])
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Comparison');
            legend('Sensor Values', 'Modeled Values',  'Location', 'northwest');
            
        end
        
          function plot_prediction_st(obj, observed, prediction, timestamps)
            figure();
            max_observed = max(observed);
            %max_observed = 100;
            
            subplot(4,1,1);
            plot(timestamps, observed - prediction);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            ylim([-max_observed,max_observed]);
            title('Residuals');
            
            subplot(4,1,2);
            plot(timestamps, observed, 'o', 'MarkerSize',1);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            ylim([-max_observed,max_observed]);
            title('Observed Values');
            
            
            subplot(4,1,3);
            plot(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            title('Precipitation');
            
            subplot(4,1,4);
            [hax, ~, ~] = plotyy(timestamps, observed, ...
                timestamps, prediction);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[-max_observed max_observed])
            set(hax(2),'YLim',[-max_observed max_observed])
            set(hax(1),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            set(hax(2),'XLim',[datenum(obj.start_date) datenum(obj.end_date)])
            title('Comparison');
            legend('Sensor Values', 'Modeled Values',  'Location', 'northwest');
            
        end
        
        function plot_prediction_yy(obj)
            figure;
            [hax, ~, ~] = plotyy(obj.usgs_timeseries_subset_timestamps, obj.y, ...
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
            A = A(2:obj.num_history_days+1);
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
            precipitation_maps = java.util.Vector(basins);
            %precipitation_maps;
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
                
                precipitation_maps.add(map);
                
            end
            
            
            for i=1:sample_count
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                precip_totals = zeros(obj.num_history_days, 6);
                for j = 1:obj.num_history_days
                    d = datenum(date - days(j-1));
                    for k = 1 : basins
                        precip_totals(j, k) = 0;
                        precipitation_map = precipitation_maps.get(k-1);
                        if precipitation_map.containsKey(d)
                            precip_totals(j, k) = precipitation_map.get(d);
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
            precipitation_maps = java.util.Vector(basins);
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
                
                precipitation_maps.add(map);
                
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
                        
                        precipitation_map = precipitation_maps.get(k-1);
                        if precipitation_map.containsKey(d)
                            precip_totals(j) = precipitation_map.get(d);
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
            obj.plot_prediction( obj.y )
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
        
        %
        % basin is index in original metabasin query
        % index is index in subgroup of metabasins used in current inversion
        %
        function predict_fdom_metabasins_single(obj, basin, index, num)
            syms fdom p3 p4 p5;
            obj.a
            
            % load the averaged values
            sqlquery = sprintf(['select timestamp,cdom from haddam_download_usgs '...
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
            %precipitation_maps is a vector so this is a problem
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
                    obj.predicted_values(i) = obj.predicted_values(i) + obj.a((index-1) * obj.num_history_days +  j ) * precip_totals(j);
                end
                
                
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                       obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + 1);
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + 1)*obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;
                 
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    month = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        mindex = 2 * obj.num_history_days + (m + 1 - start_month);
                        if(m == month)
                           obj.predicted_values(i) = obj.predicted_values(i) + obj.a(mindex) / num;
                        end
                    end
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
           obj.precipitation_running_avg = zeros(length(obj.precipitation_timestamps),1);
           len = length(obj.precipitation_running_avg);
           window = 14;
           half_window = floor(window/2);
           for i = half_window+1:len-half_window-1
              sum = 0;
              for j = 1:window
                 sum = sum + obj.precipitation_data.total_precipitation(i - half_window + j);
              end
              obj.precipitation_running_avg(i) = sum / window;
           end
           figure;
           plot(obj.precipitation_timestamps, obj.precipitation_running_avg);
           datetick('x');
           
           figure;
           subplot(2,1,1);
           plot(obj.precipitation_timestamps, obj.precipitation_running_avg);
           datetick('x');
           subplot(2,1,2);
           plot(obj.precipitation_timestamps, obj.precipitation_data.total_precipitation);
           datetick('x');
        end
        
        function build_predictor_matrix_a_b(obj, basins)
            
            % load the averaged values
            % only predicted based off summer and fall, month greater than
            % may, to avoid impact of snowmelt.
            sqlquery = sprintf(['select timestamp,cdom,discharge from haddam_download_usgs '...
                'where cdom > 0 ' ...
                'and timestamp >= to_timestamp(''%s'', ''YYYY-MM-DD'') and timestamp <= to_timestamp(''%s'', ''YYYY-MM-DD'') '...
                'order by timestamp asc'], obj.parameterization_start_date, obj.parameterization_end_date);
            
            %                 'and month > 5 ' ...  % skipping spring was
            %                 creating singular matrix

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
            obj.K = zeros(sample_count, obj.num_history_days * 2); 
            obj.y = zeros(sample_count, 1);

                        
            % organize the precipitation for lookup
            
            precipitation_maps = java.util.Vector(2);
            %precipitation_maps;
            for k = 1 : 2
                b = basins(k);
                totals = obj.metabasin_precipitation_totals.sums{b}.getArray;
                totals = double(totals);
                dates = obj.metabasin_precipitation_totals.timestamps{b}.getArray;
                dates = char(dates);
                timestamps = datenum(dates,'yyyymmdd');
                map = java.util.Hashtable;
                size(totals, 1)
                for i = 1:size(totals, 1)
                    map.put(timestamps(i), totals(i));
                end
                %map
                
                precipitation_maps.add(map);
                
            end
            
            
            for i=1:sample_count
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                precip_totals = zeros(obj.num_history_days, 2);
                for j = 1:obj.num_history_days
                    d = datenum(date - days(j-1));
                    for k = 1 : 2
                        precip_totals(j, k) = 0;
                        precipitation_map = precipitation_maps.get(k-1);
                        if precipitation_map.containsKey(d)
                            precip_totals(j, k) = precipitation_map.get(d);
                        end
                    end
                end
                
                
                for k = 1 : 2
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
                            obj.K(i, ((k-1)*obj.num_history_days) + j) = precip_totals(j, k);
                        %end
                        
                       
                    end
                end
                
                d = str2double(datestr(date, 'dd'));
                
                    
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                        obj.K(i, 2*obj.num_history_days+1) = 1;
                    else
                        obj.K(i, 2*obj.num_history_days+1) = 0;
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    haddam_fdom.day_of_year(date)
                    obj.K(i, 2*obj.num_history_days+1) = obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;  % multiply by 10000 to avoid matrix precision problems
                    
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    month = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = 2*obj.num_history_days+(m + 1 - start_month);
                     
                        if(m == month)
                            obj.K(i, index) = 1;
                        else
                            obj.K(i, index) = 0;
                        end
                    end
                end
                
                obj.y(i) = obj.usgs_timeseries_subset.cdom(i);
            end
            
            %obj.K
            
        end
        
        function predict_fdom_metabasins_a_b(obj, basins)
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
            precipitation_maps = java.util.Vector(2);
            for k = 1 : 2
                b = basins(k);
                totals = obj.metabasin_precipitation_totals.sums{b}.getArray;
                totals = double(totals);
                dates = obj.metabasin_precipitation_totals.timestamps{b}.getArray;
                dates = char(dates);
                timestamps = datenum(dates,'yyyymmdd');
                map = java.util.Hashtable;
                size(totals, 1)
                for i = 1:size(totals, 1)
                    map.put(timestamps(i), totals(i));
                end
                
                precipitation_maps.add(map);
                
            end
            
            
            obj.predicted_values = zeros(sample_count);
            
            for i=1:sample_count(1)
                date = obj.usgs_timeseries_subset_timestamps(i);
                
                obj.predicted_values(i) = obj.a(1);
                
                
                % this all needs to be switched to matrix notation
                for k = 1:2
                    
                    precip_totals = zeros(obj.num_history_days, 1);
                    for j = 1:obj.num_history_days
                        d = datenum(date - days(j));                        
                        precipitation_map = precipitation_maps.get(k-1);
                        if precipitation_map.containsKey(d)
                            precip_totals(j) = precipitation_map.get(d);
                        end
                        
                    end
                    
                    % add up the predictor variables
                    for j = 1:obj.num_history_days
                        obj.predicted_values(i) = obj.predicted_values(i) + obj.a((k-1)*obj.num_history_days +  j + 1) * precip_totals(j);
                    end
                    
                end
                                
                if(obj.seasonal_mode == obj.seasonal_mode_step )
                    if( str2double(datestr(date, 'mm')) > 9)
                       obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + 1);
                    end
                elseif(obj.seasonal_mode == obj.seasonal_mode_modeled  )
                    obj.predicted_values(i) = obj.predicted_values(i) +  obj.a(obj.num_history_days + 1)*obj.seasonal_doc_julian(haddam_fdom.day_of_year(date),2)*10000;
                 
                elseif(obj.seasonal_mode == obj.seasonal_mode_12_month )
                    month = str2double(datestr(date, 'mm'));
                    start_month = 1;
                    end_month = 12;
                    for m = start_month:end_month
                        index = 2 * obj.num_history_days + (m + 1 - start_month);
                        if(m == month)
                           obj.predicted_values(i) = obj.predicted_values(i) + obj.a(index);
                        end
                    end
                end
                
            end
        end
        
       
        function plot_history_effect_metabasins_a_b(obj, basins)
            
            A = obj.a
            figure;
                            
            hold on;
            

            for index = 1:2
                
                Ak = A((index-1)*obj.num_history_days+1 : index*obj.num_history_days);
                plot(Ak);
                Ak
% ??                index2 = index + 1;
%               Ak = A((index2-1)*obj.num_history_days+1 : index2*obj.num_history_days);
%           plot(Ak);
                title('Coefficients of precipitation influence by number of days in the past');
                ylim([-0.05,0.05]);
                
            end
            hline = refline([0 0]);
            hline.Color = 'r';
            
            legends = [obj.metabasin_precipitation_totals.name(basins(1)), obj.metabasin_precipitation_totals.name(basins(2)), 'Zero'];
            legend(legends, 'Location', 'southwest');
                            
            hold off;

            

      
        end
        
        function inverse_model_metabasins_a_b(obj)
            basins = [3 5];
            obj.build_predictor_matrix_a_b(basins);
            obj.solve_inverse;
            obj.predict_fdom_metabasins_a_b(basins);
            %obj.plot_prediction( obj.usgs_timeseries_subset.cdom )
            
            figure;
            hold on;
            plot(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom );
            plot(obj.usgs_timeseries_subset_timestamps, obj.predicted_values);
            datetick('x');
            xlim([datenum(obj.start_date) datenum(obj.end_date)]);
            
            %obj.plot_prediction_yy;
            
            hf.plot_history_effect_metabasins_a_b(basins)
        end
        
        function single_basin_compare_a_b(obj, basins)
            
            obj.predictions = zeros(length(obj.usgs_timeseries_subset_timestamps), 1);
            
            
            figure;
            %hold on;
            subplot(3,1,1);
            plot(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom);
            title('sensor');

            for i=1:2
                basins(i)
                obj.predict_fdom_metabasins_single(basins(i), i, 2);
                obj.predictions(:,i) = obj.predicted_values
                subplot(3,1,i+1);
                plot(obj.usgs_timeseries_subset_timestamps, obj.predicted_values);
                
                title('basin');
            end
            %hold off;
            
            %figure;  plotyy(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom, obj.usgs_timeseries_subset_timestamps, obj.predictions(:,1) + obj.predictions(:,2));

            %figure;  hold on; plot(obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom, obj.usgs_timeseries_subset_timestamps, obj.usgs_timeseries_subset.cdom - obj.predictions(:,2));

        end
        
    end
    
end

