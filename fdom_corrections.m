FDOM_qs = hf.usgs_timeseries.cdom;
FDOM_mv = hf.usgs_timeseries.cdom / .377;

FDOM_temp = FDOM_mv + bsxfun(@times, FDOM_mv * .01, hf.usgs_timeseries.temperature - 25);
figure; ha = plotyy(hf.usgs_timeseries_timestamps, FDOM_mv, hf.usgs_timeseries_timestamps, FDOM_temp);
set(ha(1),'ylim',[0 150]);
set(ha(2),'ylim',[0 150]);


turb_corr = exp(-0.003 * hf.usgs_timeseries.turbidity);

FDOM_temp_turb = FDOM_temp ./ turb_corr;
figure; ha = plotyy(hf.usgs_timeseries_timestamps, FDOM_temp, hf.usgs_timeseries_timestamps, FDOM_temp_turb);
set(ha(1),'ylim',[0 150]);
set(ha(2),'ylim',[0 150]);
legend('FDOM_temp', 'FDOM_temp_turb');

FDOM_temp_turb = FDOM_temp ./ turb_corr;
figure; ha = plotyy(hf.usgs_timeseries_timestamps, FDOM_mv, hf.usgs_timeseries_timestamps, FDOM_temp_turb);
set(ha(1),'ylim',[0 150]);
set(ha(2),'ylim',[0 150]);
legend('FDOM_m_v', 'FDOM_temp_turb');



FDOM_temp_turb_qs = FDOM_temp_turb * .377;

figure; ha = plotyy(hf.usgs_timeseries_timestamps, hf.usgs_timeseries.cdom, hf.usgs_timeseries_timestamps, FDOM_temp_turb_qs);
set(ha(1),'ylim',[0 60]);
set(ha(2),'ylim',[0 60]);


xmin = 37400;
xmax = 38250;
xmin = 36700;
xmax = 37400;
xmin = 14000;
xmax = 16000;
xmin = 18000;
xmax = 20000;
figure; ha = plotyy(xmin:xmax, hf.usgs_timeseries_filtered_discharge(xmin:xmax), xmin:xmax, FDOM_temp_turb_qs(xmin:xmax));
set(ha(2),'ylim',[0 60]);

x = hf.usgs_timeseries_filtered_discharge(xmin:xmax);
y = FDOM_temp_turb_qs(xmin:xmax);
figure;
plot(x, y);

figure;
for i = 1:6
    xmin = 14000 + (i-1) * 2000;
    xmax = 16000 + (i-1) * 2000;
    x = hf.usgs_timeseries_filtered_discharge(xmin:xmax);
    y = FDOM_temp_turb_qs(xmin:xmax);
    subplot(6, 1, i);
    plot(x, y);
    xlim([1 40000]);
end


% hysteresis
xmin = 1;
xmax = 10000;
x = hf.usgs_timeseries_filtered_discharge(xmin:xmax);
y = FDOM_temp_turb_qs(xmin:xmax);
figure;
plot3(x, y, hf.usgs_timeseries_timestamps(xmin:xmax));
xlabel('Discharge');
ylabel('FDOM');
zlabel('Time');


figure;
q = quiver(x(1:end-1),y(1:end-1), diff(x), diff(y));
q.AutoScale = 'off';
q.MaxHeadSize = .01;

