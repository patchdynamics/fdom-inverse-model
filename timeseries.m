matObj = matfile('fdom_corrected_daily_averages.mat');
whos(matObj)


load('fdom_corrected_daily_averages.mat');
daily_averages = fdom_corrected_daily_averages;

full_timestamps = transpose(min(daily_averages(:,1)):1:max(daily_averages(:,1)));
y_interp_empty = NaN(size(full_timestamps));
for i = 1:length(daily_averages)
    y_interp_empty(full_timestamps == daily_averages(i,1)) = daily_averages(i,2);
end
y_interp = fixgaps(y_interp_empty);

fdom_corrected_daily_averages_filled = [full_timestamps y_interp];

% find timestamps of NaN vars
ts_nan = full_timestamps(isnan(y_interp_empty));

% find indices of these in the ma series
ts_ma_modify = ts_ma;
timeseries = fdom_corrected_daily_averages_filled_detrend_60_day_ma;
timeseries(ismember(ts_ma, ts_nan),:) = [];

fdom_corrected_daily_averages_unfilled_detrend_60_day_ma = timeseries;

save 'fdom_corrected_daily_averages.mat' fdom_corrected_daily_averages fdom_corrected_daily_averages_filled fdom_corrected_daily_averages_filled_detrend_60_day_ma fdom_corrected_daily_averages_unfilled_detrend_60_day_ma


