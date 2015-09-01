datevecs = datevec(hf.usgs_timeseries_timestamps);
years = datevecs(:,1);
months = datevecs(:,2);
index = (years - 2012) * 12 + months;
index(index > 36) = []; % there's some extra past 2014

pdsi = csvread('/Users/matthewxi/Documents/Projects/PrecipGeoStats/PDSI/hrap_jacobi/Palmer.matlab.txt');
pdsi = pdsi(:,10);
pdsi_series = pdsi(index);


l = length(index);
X = [ones(l, 1) pdsi_series ];
y = hf.usgs_timeseries.cdom(1:l);

[b,bint,r,rint,stats] = regress(y,X); 

ym = b(1) + b(2) * pdsi_series ; 


figure; 
[hax, hLine1, hLine2] = ...
plotyy(hf.usgs_timeseries_timestamps(1:l), hf.usgs_timeseries.cdom(1:l), hf.usgs_timeseries_timestamps(1:l), ym);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');

figure; 
[hax, hLine1, hLine2] = ...
plotyy(hf.usgs_timeseries_timestamps(1:l), hf.usgs_timeseries.cdom(1:l), hf.usgs_timeseries_timestamps(1:l), pdsi_series);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');


% mass flow
l = length(index);
X = [ones(l, 1) pdsi_series ];
y = hf.usgs_timeseries.doc_mass_flow(1:l);
% y = hf.usgs_timeseries_filtered_doc_mass_flow(1:l);

[b,bint,r,rint,stats] = regress(y,X); 

ym = b(1) + b(2) * pdsi_series ; 


figure; 
[hax, hLine1, hLine2] = ...
plotyy(hf.usgs_timeseries_timestamps(1:l), y, hf.usgs_timeseries_timestamps(1:l), ym);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');

figure; 
[hax, hLine1, hLine2] = ...
plotyy(hf.usgs_timeseries_timestamps(1:l), y, hf.usgs_timeseries_timestamps(1:l), pdsi_series);
datetick(hax(1), 'keeplimits');
datetick(hax(2), 'keeplimits');
