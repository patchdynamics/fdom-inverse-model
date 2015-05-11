data =  csvread('../seasonal DOC/seasonal_DOC_proxy/Sheet1-Table 1.csv');
figure; plot(data(1:end,1), data(1:end,3))

days = data(1:end,1);
seasonal_doc = data(1:end,3);

interpolated = zeros(365, 1);
interpolated(1) = seasonal_doc(1);
for(i = 2:365 )
    past = find(days < i);
    future = find(days >= i);
    
    previous_index = past(end);
    next_index = future(1);
    
    i
    before = days(previous_index)
    after = days(next_index)
    
    % amount to interpolate
    current = i - before;
    
    doc_previous = seasonal_doc(previous_index);
    doc_next = seasonal_doc(next_index);
    
    interpolated(i) = doc_previous +  (doc_next - doc_previous) / (after - before) * current;
end
interpolated

figure; plot(interpolated)

figure; plotyy(1:365, interpolated, data(1:end,1), data(1:end,3));

num = 365;
figure;
plotyy(1:num, interpolated(1:num), data(1:end,1), data(1:end,3));

output = [transpose(1:365), interpolated];
output
csvwrite('prepared_seasonal_doc.csv', output);


snowmelt = csvread('../snow/Zonal1-not-accurate.txt', 0, 12);
figure;
subplot(2,1,1);
plot(snowmelt(1:3*365))
xlim([0,3*365]);

subplot(2,1,2);
[hax, ~, ~] = plotyy(hf.usgs_timeseries_subset_timestamps, hf.usgs_timeseries_subset.cdom, ...
    hf.usgs_timeseries_subset_timestamps, hf.fdom_predicted);
datetick(hax(1));
datetick(hax(2));
set(hax(1),'YLim',[0 60])
set(hax(2),'YLim',[0 60])
set(hax(1),'XLim',[datenum(hf.start_date) datenum(hf.end_date)])
set(hax(2),'XLim',[datenum(hf.start_date) datenum(hf.end_date)])
title('Modeled and Sensor FDOM');
legend('Sensor FDOM', 'Modeled FDOM');

