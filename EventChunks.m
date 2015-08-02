% chunk out the sub-timeseries
figure;
event_count = length(hf.event_start_dates);
max_lag = NaN(event_count,1)
start = 1;
days_window = 30;
mode = 3
for i = start:event_count
    start_index = find(hf.usgs_timeseries_timestamps < hf.event_start_dates(i), 1, 'last' );
    if(isempty(start_index))
        continue;
    end
    end_index = start_index + 4 * 24 * days_window; % 8 day window for FDOM from inverse model
    max_index = length(hf.usgs_timeseries_filtered_discharge);
    if(end_index > max_index)
        end_index = max_index;
    end
    discharge = hf.usgs_timeseries.discharge(start_index:end_index);
    discharge = hf.usgs_timeseries_filtered_discharge(start_index:end_index);
    
    fdom = hf.usgs_timeseries.cdom(start_index:end_index);
    time = ((start_index:end_index) - start_index) / 4 / 24;
    if(mode == 1)
        [hax, hLine1, hLine2] = plotyy(time, discharge, time, fdom);
        set(hax(2),'YLim',[20 50])
        set(hax(1),'YLim',[5000 60000])
        title(num2str(i));
        pause

    elseif(mode == 2)
        [XCF,lags,bounds] = crosscorr(discharge,fdom,800);
        %crosscorr(discharge,fdom);
        plot(lags/4/24, XCF, '*')
        ylim([-1 1]);
        title(strcat(num2str(i) , '   min   ' , num2str(start_index) , '   max   ' , num2str(end_index)));
        hline = refline([0 bounds(1)]);
        hline.Color = 'r';
        hline2 = refline([0 bounds(2)]);
        hline2.Color = 'r';
        pause
 
    elseif(mode == 3)
        [XCF,lags,bounds] = crosscorr(discharge,fdom,800);
        max_lag(i) = lags(XCF == max(XCF));
    end
    
end

if(mode == 3)
   figure;
   plot(hf.event_start_dates, max_lag/4/24, '*'); 
   datetick('x');
end
