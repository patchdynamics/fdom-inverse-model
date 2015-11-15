% detrending

% regression
% cannot use month because this data is continuous
% cannot use julian day because that's way too many regressors
% we can calculate a julian day average however

y_daily_original = daily_averages(:,2);

y = daily_averages(:,2);
timestamps = daily_averages(:,1);

y = y_interp;
timestamps = full_timestamps;

% 1) Detrend linear
X = [ones(length(timestamps),1) timestamps];

b = regress(y, X);
yn = b(1) + b(2)*timestamps;

y_linear_detrend = y - yn + mean(y);

figure; hold on; plot(timestamps, y); plot(timestamps, yn); hold off;
figure; hold on; plot(timestamps, y); plot(timestamps, yn); plot(timestamps, y_linear_detrend); hold off;

% julian day averages
y = y_linear_detrend;
julian_days = datevec2doy( datevec(timestamps));
count = zeros(366,1);
total = zeros(366,1);
for i = 1:length(julian_days)
    day = julian_days(i);
    count(day) = count(day) + 1;
    total(day) = total(day) + y_linear_detrend(i);
end
julian_day_avg = total ./ count;

% get the 30 day lagged moving average
circular = [julian_day_avg; julian_day_avg; julian_day_avg];
movavg = tsmovavg(circular, 's', 30,1);
one_cycle = movavg(366+15:366+15+365,:);

% now detrend with the moving average
y_detrended = y_linear_detrend;
for i = 1:length(timestamps)
    trend = one_cycle(julian_days(i));
    y_detrended(i) = y_detrended(i) - trend + mean(one_cycle);
end

% try to get 2 sinusoids out of the trend signal
i = transpose(1:length(one_cycle));
X = [ones(length(one_cycle),1) sin(2*pi*i/length(one_cycle)) ];
y = one_cycle;
b = regress(y, X);

y_cycle = X * b;

figure; hold on; plot(one_cycle); plot(y_cycle); hold off;



% another approach : just remove the moving average
% need to start by interpolating the entire timeseries

full_timestamps = transpose(min(timestamps):1:max(timestamps));
y_interp = NaN(size(full_timestamps));
for i = 1:length(timestamps)
    y_interp(full_timestamps == timestamps(i)) = y_daily_original(i);
end
y_interp = fixgaps(y_interp);

window = 29;
interval = floor(window / 2);
center = interval + 1;
movavg = tsmovavg(y_interp, 's', window,1);
figure; 
hold on;
plot(full_timestamps(center:end-interval), y_interp(center:end-interval));
plot(full_timestamps(center:end-interval), movavg(window:end)); 
plot(full_timestamps(center:end-interval), movavg(window:end)-min(y_interp)); 
datetick('x');
hold off;

y_detrended_ma = y_interp(center:end-interval) - movavg(window:end);
y_detrended_timestamps = full_timestamps(center:end-interval);

innovations = y_interp(15:end-14) - movavg(29:end);
innovations = y_interp(15:end-14) - (movavg(29:end) - min(y_interp));
figure; plot(full_timestamps(15:end-14), innovations); datetick('x');


figure; 
hold on; 
plot(full_timestamps(center:end-interval), innovations);
plot(full_timestamps, y_interp);
hold off;
datetick('x');

hf.y = innovations(1:end);
hf.build_predictor_matrix(full_timestamps(center:end-interval));
s = size(hf.K);
%hf.K(:,s(2)+1) = innovations(1:end-1);  % making it AR(1)
% 
[b,i,r,x,stats] = regress(hf.y, hf.K);

yn = hf.K * b;

figure; hold on; plot(hf.y); plot(yn); hold off;



% back to the fourier of it all

y = y_interp;
timestamps = full_timestamps;
X = [ones(length(timestamps),1), sin(2*pi*timestamps / 365), cos(2*pi*timestamps / 365), sin(4*pi*timestamps / 365), cos(4*pi*timestamps / 365), sin(6*pi*timestamps / 365), cos(6*pi*timestamps / 365)];

[b,i,r,x,stats] = regress(y, X);
yn = X * b;

figure;
hold on;
plot(yn);
plot(y_interp);
hold off;




% then there is the idea of the MA process
window = 60;
movavg = tsmovavg(y_interp, 's', window,1);
y_ma_baseflow = y_interp(window:end) - movavg(window:end);
figure; hold on; plot(y_interp(window:end)); plot(movavg(window+window/2:end)); plot(y_ma_baseflow); hold off;