insolation_data = csvread('../Insolation.csv')


l = length(hf.usgs_timeseries.cdom);
months = month(hf.usgs_timeseries_timestamps);
insolation_series = insolation_data(months,2);

X = [ones(l, 1) insolation_series ];
y = hf.usgs_timeseries.cdom;

[b,bint,r,rint,stats] = regress(y,X);   

ym = b(1) + b(2) * insolation_series; 

figure; plotyy((1:l), hf.usgs_timeseries.cdom, (1:l), ym);
% R^2 around .35


% other models
X = [ones(l, 1) log(insolation_data(months,2))];
y = hf.usgs_timeseries.cdom;

[b,bint,r,rint,stats] = regress(y,X);   

ym = b(1) + b(2) * insolation_data(months,2); 


figure; 
[hax, hLine1, hLine2] = plotyy(hf.usgs_timeseries_timestamps, hf.usgs_timeseries.cdom, hf.usgs_timeseries_timestamps, ym);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');


% temperature
% going to need to match up by day somehow
% get year and get day, index into csv file

datevecs = datevec(hf.usgs_timeseries_timestamps);
days_of_years = datevec2doy(datevecs);
years = datevecs(:,1);
index = (years - 2012) * 365 + days_of_years;
index(index > 1094) = []; % there's some extra past 2014

temperature_avg = csvread('../R/temperature_avg.matlab.csv');

temperatures = temperature_avg(index,4);
l = length(index);
X = [ones(l, 1) temperatures ];
y = hf.usgs_timeseries.cdom(1:l);

[b,bint,r,rint,stats] = regress(y,X); 

ym = b(1) + b(2) * temperatures ; 


figure; 
[hax, hLine1, hLine2] = ...
plotyy(hf.usgs_timeseries_timestamps(1:l), hf.usgs_timeseries.cdom(1:l), hf.usgs_timeseries_timestamps(1:l), ym);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');


