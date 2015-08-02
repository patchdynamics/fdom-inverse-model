% Area of CT River Above Haddam in sq Miles
A = 10879.797;

% get discharge ready
y = hf.usgs_timeseries.discharge;
% deal with empty data
tf = isnan(y);
ix = 1:numel(y);
y(tf) = interp1(ix(~tf),y(~tf),ix(tf));

discharge = [hf.usgs_timeseries_timestamps, hf.usgs_timeseries_filtered_discharge];



hf.load_usgs_daily_means

y = hf.usgs_daily_means.discharge;
% deal with empty data
tf = isnan(y);
ix = 1:numel(y);
y(tf) = interp1(ix(~tf),y(~tf),ix(tf));

discharge = [hf.usgs_daily_means_timestampes, y];


hysep = f_hysep(discharge(1:100, :), A);


% chunk out the sub-timeseries
for i = 1:length(hf.event_start_dates)
   start_index = find(hf.usgs_timeseries_timestamps < hf.event_start_dates(i), 1, 'last' );
   if(isempty(start_index))
       continue;
   end
   end_index = start_index + 4 * 24 * 8; % 8 day window for FDOM from inverse model
   discharge = hf.usgs_timeseries.discharge(start_index:end_index);
   discharge = hf.usgs_timeseries_filtered_discharge(start_index:end_index);

   fdom = hf.usgs_timeseries.cdom(start_index:end_index);
   plotyy((start_index:end_index), discharge, start_index:end_index, fdom);
   pause
end



% some plots
figure; 
plot(hf.event_total_sizes, max_lag/4/24, '*'); title('event size vs lag')


x1 = transpose(hf.event_total_sizes);
[b,bint,r,rint,stats]  = regress(max_lag/4/24,[ones(size(x1)) x1] );

figure; insolation = csvread('../Insolation.csv')

l = length(hf.usgs_timeseries.cdom);
months = month(hf.usgs_timeseries_timestamps);

X = [ones(l) insolation(months,2)]

Y = hf.usgs_timeseries.cdom;
hold on;
plot(hf.event_total_sizes, max_lag/4/24, '*'); title('event size vs lag')
plot(hf.event_total_sizes, y)
hold off;


figure;
MonthNum = month(hf.event_start_dates);
plot(MonthNum, max_lag/4/24, '*'); title('month size vs lag')


x1 = transpose(MonthNum);
[b,bint,r,rint,stats]  = regress(max_lag/4/24,[ones(size(x1)) x1] );
y = b(1) + b(2) * x1;

x1 = transpose(MonthNum);
[b,bint,r,rint,stats]  = regress(max_lag/4/24,[ones(size(x1)) x1 x1.^2] );
y = b(1) + b(2) * x1 + b(3) * x1.^2;

figure; 
hold on;
plot(x1, max_lag/4/24, '*'); title('month vs lag')
plot(x1, y)
hold off;


