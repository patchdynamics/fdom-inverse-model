% plot two timeseries
figure; subplot(2,1,1); plot(double(hf.metabasin_precipitation_totals.sums{5}.getArray)); subplot(2,1,2); plot(double(hf.metabasin_precipitation_totals.sums{6}.getArray));

% get full timestamp series
dates = hf.metabasin_precipitation_totals.timestamps{5}.getArray;
dates = char(dates);
ta = datenum(dates,'yyyymmdd');

dates = hf.metabasin_precipitation_totals.timestamps{6}.getArray;
dates = char(dates);
tb = datenum(dates,'yyyymmdd');

% should be using timeseries object, but getting an error even when using
% the example
%ts = timeseries(double(hf.metabasin_precipitation_totals.sums{5}.getArray), char(hf.metabasin_precipitation_totals.timestamps{6}.getArray));
% so using the old method

x_maps = java.util.Vector(2);
obj = hf;
basins = [ 3 5 ];
for k = 1:2
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
    
    x_maps.add(map); 
end



t1 = datetime('01-Dec-2012');
t2 = datetime('31-Dec-2014');
t = datenum(t1:t2);

sample_count = length(t);
series = zeros(2, sample_count);

for i=1:sample_count;
    date = t(i);
    for k = 1:2
        x_map = x_maps.get(k-1);
        if x_map.containsKey(date)
            series(k, i) = x_map.get(date);
        end
    end
end
series

% plot two timeseries
figure; subplot(2,1,1); plot(series(1,:)); subplot(2,1,2); plot(series(2,:));


% compare diff
% then compare diff of log - differences may be in the smaller storms

% difference of timeseries
a = series(1,:);
b = series(2,:)
diff = a - b;
figure; plot(diff);

start = 200;
stop = 500;
figure;
plotyy(start:stop, diff(start:stop), start:stop, a(start:stop));

