data = hf.usgs_timeseries_filtered_doc_mass_flow_eq2;

figure; findpeaks(data, 'MinPeakProminence',100000);

[Maxima,MaxIdx] = findpeaks(data, 'MinPeakProminence',100000);

% find minima
DataInv = 1.01*max(data) - data;
[Minima,MinIdx] = findpeaks(DataInv, 'MinPeakProminence',100000);
figure; findpeaks(DataInv);

figure;
subplot(2,1,1);
findpeaks(data,    'MinPeakProminence',100000);
subplot(2,1,2);
findpeaks(DataInv, 'MinPeakProminence',100000);

numberOfEvents = length(begin);
EventIdxVector = zeros(numberOfEvents, 1);
PrecipitationStartIdxVector = zeros(numberOfEvents, 1);
PrecipitationEndIdxVector = zeros(numberOfEvents, 1);
FlowStartIdxVector = zeros(numberOfEvents, 1);
FlowEndIdxVector = zeros(numberOfEvents, 1);

for i = 1:length(begin)
    EventIdx = find(hf.usgs_timeseries_timestamps == begin(i),1);
    
    %get the first maxima
    MaximaIdx = MaxIdx(find(MaxIdx > EventIdx,1))
    
    %check for captured minima
    MinimaIdx = MinIdx(find(MinIdx > EventIdx,1))
    if MinimaIdx < MaximaIdx
        % there is a minima between the event start and peak
        % use the peak
        PrecipitationStartIdx = EventIdx;
    else
        % use the previous minima
        MinimaIdx = max(MinIdx(find(MinIdx < EventIdx), 1))
        PrecipitationStartIdx = MinimaIdx
    end
    FlowStartIdx = MinimaIdx
    
    
    PrecipitationEndIdx = MaximaIdx
    
    % now we have bounded the precipitation event
    
    % bound the discharge event
    MinimaIdx = MinIdx(find(MinIdx > MaximaIdx,1))
    FlowEndIdx = MinimaIdx;
    
    EventIdxVector(i) = EventIdx;
    PrecipitationStartIdxVector(i) = PrecipitationStartIdx;
    PrecipitationEndIdxVector(i) = PrecipitationEndIdx;
    FlowStartIdxVector(i) = FlowStartIdx;
    FlowEndIdxVector(i) = FlowEndIdx;
    
end

%figure;
num = length(EventIdxVector);
for i = 1:num
    %row = floor(i / 4)+1
    %col = mod(i, 4) + 1
    %i
    %subplot(num, 1, i);
    
    start =  min([FlowStartIdxVector(i) PrecipitationStartIdxVector(i)]);
    domain = start:FlowEndIdxVector(i);
    figure;
    plot(hf.usgs_timeseries_timestamps(domain), hf.usgs_timeseries_filtered_doc_mass_flow_eq2(domain));
    datetick('x');
    line([FlowStartIdxVector(i), FlowStartIdxVector(i)], [0, 10000000], 'Color', 'm')
    line([FlowEndIdxVector(i), FlowEndIdxVector(i)], [0, 10000000], 'Color', 'm')
    line([PrecipitationStartIdxVector(i), PrecipitationStartIdxVector(i)], [0, 10000000], 'Color', 'k')
    line([PrecipitationEndIdxVector(i), PrecipitationEndIdxVector(i)], [0, 10000000], 'Color', 'k')
    line([EventIdxVector(i), EventIdxVector(i)], [0, 10000000], 'Color', 'g')
end

EventIndices = [transpose(FlowStartIdxVector), transpose(FlowEndIdxVector), transpose(PrecipitationStartIdxVector), transpose(PrecipitationEndIdxVector), EventIdxVector]


for i = 1:length(EventIndicesEdit)

    FlowStartIdx = EventIndicesEdit(i, 1);
    FlowEndIdx = EventIndicesEdit(i, 2);
    PrecipitationStartIdx = EventIndicesEdit(i, 3);
    PrecipitationEndIdx = EventIndicesEdit(i, 4);
    EventIdx = EventIndicesEdit(i, 5);

    FlowStartTime = hf.usgs_timeseries_timestamps(FlowStartIdx);
    FlowEndTime = hf.usgs_timeseries_timestamps(FlowEndIdx);
    PrecipitationStartTime = hf.usgs_timeseries_timestamps(PrecipitationStartIdx);
    PrecipitationEndTime = hf.usgs_timeseries_timestamps(PrecipitationEndIdx);
    EventTime = hf.usgs_timeseries_timestamps(EventIdx);

    event_precipitation = sum(hf.precipitation_data.total_precipitation( hf.precipitation_timestamps >= PrecipitationStartTime &  hf.precipitation_timestamps <= PrecipitationEndTime ) )
    EventIndicesEdit(i, 7) = event_precipitation;
    
    %mass_flow_series = hf.usgs_timeseries.doc_mass_flow_eq2( hf.usgs_timeseries_timestamps >= FlowStartTime & hf.usgs_timeseries_timestamps <= FlowEndTime );
    mass_flow_series = hf.usgs_timeseries_filtered_doc_mass_flow_eq2( hf.usgs_timeseries_timestamps >= FlowStartTime & hf.usgs_timeseries_timestamps <= FlowEndTime );

    mass_flow_series = mass_flow_series * 15 * 60; % change units to mg/15min, the time step of the integral
    event_mass_flow = trapz(mass_flow_series);
    EventIndicesEdit(i, 8) = event_mass_flow;
end


cc=hsv(14);
figure; 
subplot(2,1,1);
hold on
for i = 1:length(EventIndicesEdit)
    FlowStartTime = hf.usgs_timeseries_timestamps(EventIndicesEdit(i,1));
    thismonth = str2double(datestr(FlowStartTime, 'mm'));
    season = floor(thismonth / 3) + 1
    %if season ~= 4
    %    continue
    %end
    plot(EventIndicesEdit(i,7), EventIndicesEdit(i,8), '*', 'Color', cc(thismonth,:));
    xlabel('Event Precipitation')
    ylabel('Integrated Mass Flow')
end
hold off
subplot(2,1,2); 
hold on;
for i = 1:12
   plot(i,1, '*', 'Color', cc(i,:))
end
hold off

