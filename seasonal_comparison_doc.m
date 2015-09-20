
spring = month(hf.usgs_timeseries_timestamps) < 6;
summer = (month(hf.usgs_timeseries_timestamps) >= 6) & (month(hf.usgs_timeseries_timestamps) <= 8);
fall = month(hf.usgs_timeseries_timestamps) > 8;

figure;
subplot(2,1,1)
hold on;
plot(hf.usgs_timeseries_filtered_discharge(spring), hf.usgs_timeseries_filtered_doc_concentration(spring));
plot(hf.usgs_timeseries_filtered_discharge(summer), hf.usgs_timeseries_filtered_doc_concentration(summer));
plot(hf.usgs_timeseries_filtered_discharge(fall), hf.usgs_timeseries_filtered_doc_concentration(fall));
legend('spring', 'summer', 'fall')
hold off;

y = hf.usgs_timeseries_filtered_doc_mass_flow;
subplot(2,1,2)
hold on;
plot(hf.usgs_timeseries_filtered_discharge(spring), y(spring));
plot(hf.usgs_timeseries_filtered_discharge(summer), y(summer));
plot(hf.usgs_timeseries_filtered_discharge(fall), y(fall));
legend('spring', 'summer', 'fall')
hold off;




figure;
subplot(2,1,1)
hold on;
plot(hf.usgs_timeseries_filtered_discharge(spring), hf.usgs_timeseries_filtered_doc_concentration(spring));
legend('fall')
hold off;

y = hf.usgs_timeseries_filtered_doc_mass_flow;
subplot(2,1,2)
hold on;
plot(hf.usgs_timeseries_filtered_discharge(fall), y(fall));
legend('fall')
hold off;



figure;
y = hf.usgs_timeseries_filtered_doc_mass_flow;
hold on;
plot(hf.usgs_timeseries_filtered_discharge(fall), y(fall));
legend('fall')
hold off;


figure;
plotyy(hf.usgs_timeseries_timestamps, hf.usgs_timeseries_filtered_discharge, hf.usgs_timeseries_timestamps, hf.usgs_timeseries_filtered_doc_mass_flow);












spring = month(hf.usgs_timeseries_timestamps) < 6;
summer = (month(hf.usgs_timeseries_timestamps) >= 6) & (month(hf.usgs_timeseries_timestamps) <= 8);
fall = month(hf.usgs_timeseries_timestamps) > 8;

figure;
subplot(2,1,1)
hold on;
plot(hf.usgs_timeseries_filtered_discharge(spring), hf.usgs_timeseries_filtered_doc_concentration_eq2(spring));
plot(hf.usgs_timeseries_filtered_discharge(summer), hf.usgs_timeseries_filtered_doc_concentration_eq2(summer));
plot(hf.usgs_timeseries_filtered_discharge(fall), hf.usgs_timeseries_filtered_doc_concentration_eq2(fall));
legend('spring', 'summer', 'fall')
hold off;

y = hf.usgs_timeseries_filtered_doc_mass_flow_eq2;
subplot(2,1,2)
hold on;
plot(hf.usgs_timeseries_filtered_discharge(spring), y(spring));
plot(hf.usgs_timeseries_filtered_discharge(summer), y(summer));
plot(hf.usgs_timeseries_filtered_discharge(fall), y(fall));
legend('spring', 'summer', 'fall')
hold off;


