insolation_data = csvread('../Insolation.csv')

mode = 2;
switch mode
    case 1
        timeseries = hf.usgs_timeseries.cdom;
        timestamps = hf.usgs_timeseries_timestamps;
    case 2
        timeseries = hf.usgs_daily_means.cdom;
        timestamps = hf.usgs_daily_means_timestampes;
    case 3
        timeseries = hf.usgs_daily_means.doc_mass_flow;
        timestamps = hf.usgs_daily_means_timestampes;
end
        
l = length(timeseries);
months = month(timestamps);
insolation_series = insolation_data(months,2);

X = [ones(l, 1) insolation_series ];
y = timeseries;

[b,bint,r,rint,stats] = regress(y,X);   

ym = b(1) + b(2) * insolation_series; 

figure; plotyy((1:l), timeseries, (1:l), ym);
% R^2 around .35
figure;
hold on;
plot(timestamps, timeseries);
plot(timestamps, ym);
datetick('x');
ylabel('Mass Flow');
legend('Sensor', 'Modeled');
hold off;


% other models
X = [ones(l, 1) log(insolation_data(months,2))];
y = hf.usgs_timeseries.cdom;

[b,bint,r,rint,stats] = regress(y,X);   

ym = b(1) + b(2) * insolation_data(months,2); 


figure; 
[hax, hLine1, hLine2] = plotyy(hf.usgs_timeseries_timestamps, hf.usgs_timeseries.cdom, hf.usgs_timeseries_timestamps, ym);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');

% insolation with mass flow

% we have both tidal filtered and unfiltered
% hf.usgs_timeseries.doc_mass_flow
% R square of .011

% hf.usgs_timeseries_filtered_doc_mass_flow
% R square of .016


X = [ones(l, 1) insolation_series ];
% X = [ones(l, 1) log(insolation_series)];



%y = hf.usgs_timeseries_filtered_doc_mass_flow;

% y = log( hf.usgs_timeseries_filtered_doc_mass_flow);
% even worse, R2 of .0005

y = hf.usgs_timeseries.doc_mass_flow;

[b,bint,r,rint,stats] = regress(y,X);   

ym = b(1) + b(2) * insolation_series; 

figure; plotyy((1:l), y, (1:l), ym);

% temperature
% going to need to match up by day somehow
% get year and get day, index into csv file

datevecs = datevec(timestamps);
days_of_years = datevec2doy(datevecs);
years = datevecs(:,1);
index = (years - 2012) * 365 + days_of_years;
index(index > 1094) = []; % there's some extra past 2014.  skip 2015

temperature_avg = csvread('../R/temperature_avg.matlab.interp.csv');

temperatures = temperature_avg(index,4);
l = length(temperatures);
X = [ones(l, 1) temperatures ];

y = timeseries(1:l);
% y = hf.usgs_timeseries_filtered_doc_mass_flow;


[b,bint,r,rint,stats] = regress(y,X); 

ym = b(1) + b(2) * temperatures ; 

figure; 
hold on;
plot(timestamps(1:l), y);
plot(timestamps(1:l), ym);
datetick('x', 'keeplimits');
hold off;

figure; 
[hax, hLine1, hLine2] = ...
plotyy(timestamps(1:l), y, timestamps(1:l), temperatures);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');

% insolation NARR
datevecs = datevec(timestamps);
days_of_years = datevec2doy(datevecs);
years = datevecs(:,1);
index = (years - 2012) * 365 + days_of_years;
index(index > 1094) = []; % there's some extra past 2014.  skip 2015

dswrf = csvread('../R/dswrf.csv');



dswrfs = dswrf(index,4);
indicator = dswrfs;
indicator = lastthree / 100000;
indicator = lastthree.^2 / 100000;
indicator = log(lastthree / 100000)
indicator = log(dswrfs / 100000)
indicator = log(lastfive / 100000)
indicator = log(dswrfs);


l = length(indicator);
X = [ones(l, 1) indicator ];


y = timeseries(1:l);
% y = hf.usgs_timeseries_filtered_doc_mass_flow;


[b,bint,r,rint,stats] = regress(y,X); 
stats(1)

ym = b(1) + b(2) * indicator ; 

figure; 
hold on;
plot(timestamps(1:l), y(1:l));
plot(timestamps(1:l), ym(1:l));
datetick('x', 'keeplimits');
hold off;

r = y - ym;
figure;
plot(timestamps(1:l), r(1:l));

figure; 
[hax, hLine1, hLine2] = ...
plotyy(timestamps(1:l), y, timestamps(1:l), temperatures);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');


% mass flow
datevecs = datevec(hf.usgs_timeseries_timestamps);
days_of_years = datevec2doy(datevecs);
years = datevecs(:,1);
index = (years - 2012) * 365 + days_of_years;
temperature_avg = csvread('../R/temperature_avg.matlab.interp.csv');
temperatures = temperature_avg(index,4);
l = length(temperatures);
X = [ones(l, 1) temperatures ];
y = hf.usgs_timeseries_filtered_doc_mass_flow

[b,bint,r,rint,stats] = regress(y,X); 
ym = b(1) + b(2) * temperatures ; 




% Pete's seasonal DOC production in 1st Order
seasonal_doc_julian = csvread('prepared_seasonal_doc.csv');
min_doc =  min(seasonal_doc_julian(:,2))
seasonal_doc_normalized = (seasonal_doc_julian(:,2) - min_doc) / (max(seasonal_doc_julian(:,2) - min_doc));

min_insol = min(insolation_data(:,3));
insolation_normalized = (insolation_data(:,3) - min_insol) / (max(insolation_data(:,3)) - min_insol);

julian_days = zeros(1,13);
for i = 1:12
    julian_days(i) = datevec2doy(datevec(strcat('2012-', int2str(i),  '-01')));
end
julian_days(13) = 366; % complete interval for interp
insolation_normalized(13) = insolation_normalized(1);

insolation_julian = horzcat(transpose(julian_days), insolation_normalized);

% get interpolated insolation avg for entire year
insolation_julian = interp1(insolation_julian(:,1), insolation_julian(:,2), (1:365));
% could smooth this out also using a circular filter..

C = seasonal_doc_normalized.*transpose((1-insolation_julian)); % multiply the normalized metrics together
C = C / max(C);

figure;
hold on;
plot(seasonal_doc_normalized);
plot(1 - insolation_julian);
plot(C);
hold off;
legend('Normalized Julian 1st Order DOC', 'Normalized Insolation', 'Indicator');

% inverse model whatever we want to
datevecs = datevec(timestamps);
days_of_years = datevec2doy(datevecs);
days_of_years(days_of_years == 366) = 365;

% choose indicator
variable_timeseries = C(days_of_years);
%variable_timeseries = seasonal_doc_normalized(days_of_years);

l = length(timestamps);
X = [ones(l, 1) variable_timeseries ];
y = timeseries;

[b,bint,r,rint,stats] = regress(y,X);   

ym = b(1) + b(2) * variable_timeseries; 
figure; 
hold on;
plot(timestamps(1:l), y);
plot(timestamps(1:l), ym);
datetick('x', 'keeplimits');
hold off;
stats(1)
stats(3)
b(2)



% snow
snow_melt = csvread('/Users/matthewxi/Documents/Projects/PrecipGeoStats/snow/snow_scatch.txt');
datevecs = datevec(timestamps);
years = datevecs(:,1);
julian_days = datevec2doy(datevecs);

index = (years - 2012) * 365 + julian_days;
snow_melt_series = snow_melt(:,2);
variable_timeseries = snow_melt_series(index);
%variable_timeseries = nthroot(snow_melt_series(index),4);
%variable_timeseries = snow_melt_series(index) > 1;

l = length(timestamps);
X = [ones(l, 1) variable_timeseries ];
y = timeseries;

[b,bint,r,rint,stats] = regress(y,X);   

ym = b(1) + b(2) * variable_timeseries; 


figure; 
hold on;
plot(timestamps(1:l), y);
plot(timestamps(1:l), ym);
datetick('x', 'keeplimits');
hold off;


figure; 
[hax, hLine1, hLine2] = plotyy(timestamps, y, timestamps, ym);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');










% subplots
years = strcat(num2str(temperature_avg(:,2)));
yeardates = datenum(years, 'yyyy');
tempdates = yeardates + temperature_avg(:,3)

figure;
subplot(5,1,1); 
plot(hf.usgs_timeseries_timestamps, hf.usgs_timeseries_filtered_doc_mass_flow);
datetick('x', 'keeplimits');
ylabel('DOC') 

subplot(5,1,2); 
plot( hf.precipitation_timestamps, hf.precipitation_running_avg);
ylabel('P Running Avg'); 

subplot(5,1,3); 
plot(hf.usgs_timeseries_timestamps, hf.usgs_timeseries.cdom); 
ylabel('CDOM');

subplot(5,1,4); 
plot(snow_timestamps, snow_melt(:,2)); 
datetick('x');
ylabel('Snow Melt');

subplot(5,1,5); 
plot(tempdates, temperature_avg(:,4)); 
datetick('x');
ylabel('T');


samexaxis('abc','xmt','on','ytac','join','yld',1)



% mass flow and melting
snow_melt_timestamps = datenum(num2str(snow_melt(:,1)), 'yyyymmdd');

figure;
subplot(2,1,1); 
plot(snow_melt_timestamps, snow_melt_series); 
datetick('x');
ylabel('Snow Melt');

subplot(2,1,2); 
max_observed = max(hf.y);
[hax, ~, ~] = plotyy(hf.usgs_timeseries_subset_timestamps, hf.y, ...
                hf.usgs_timeseries_subset_timestamps, hf.predicted_values);
            datetick(hax(1));
            datetick(hax(2));
            set(hax(1),'YLim',[0 max_observed])
            set(hax(2),'YLim',[0 max_observed])
            set(hax(1),'XLim',[datenum(hf.start_date) datenum(hf.end_date)])
            set(hax(2),'XLim',[datenum(hf.start_date) datenum(hf.end_date)])
            title('Comparison');
            legend('Sensor Values', 'Modeled Values',  'Location', 'northwest');
ylabel('DOC Mass Flow');

samexaxis()




% precip series
precip_totals = zeros(length(timestamps),1);
for j = 1:length(timestamps)
                    
                    if isKey(hf.precipitation_map, timestamps(j))
                        precip_totals(j) = hf.precipitation_map(timestamps(j));
                    end
end




% moving average
% last 3 days (transit time)

lastthree = zeros(length(dswrfs),1);
lastthree(1) = dswrfs(1);
lastthree(2) = dswrfs(2);
for i=3:length(dswrfs)
    lastthree(i) = dswrfs(i) + dswrfs(i-1) + dswrfs(i-2);
    lastthree(i) = lastthree(i) / 3;
end

lastfive = zeros(length(dswrfs),1);
lastfive(1) = dswrfs(1);
lastfive(2) = dswrfs(2);
lastfive(3) = dswrfs(3);
lastfive(4) = dswrfs(4);
for i=5:length(dswrfs)
    lastfive(i) = dswrfs(i) + dswrfs(i-1) + dswrfs(i-2) + dswrfs(i-3) + dswrfs(i-4);
    lastfive(i) = lastfive(i) / 5;
end

len = 7;
indicator = zeros(length(dswrfs),1);
for i = 1:len-1
    indicator(i) = dswrfs(i);
end
for i=len:length(dswrfs)
    for j = 0:len-1
        indicator(i) = indicator(i) + dswrfs(i-j); 
    end
    indicator(i) = indicator(i) / len;
end
indicator = log(indicator);

l = length(indicator);
X = [ones(l, 1) indicator ];


y = timeseries(1:l);
% y = hf.usgs_timeseries_filtered_doc_mass_flow;


[b,bint,r,rint,stats] = regress(y,X); 
stats(1)

