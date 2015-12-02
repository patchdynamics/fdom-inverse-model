ts = fdom_timeseries_filled;
timestamps = ts(:,1);
fdom = ts(:,2);
ema = tsmovavg(fdom, 'e', 90, 1);
figure; hold on; plot(fdom); plot(ema);

y_detrend_ma = fdom(90:end) - ema(90:end);
y_detrend_ma = y_detrend_ma - min(y_detrend_ma);
timestamps = timestamps(90:end);

Xsinusoid = [sin(2*pi*timestamps / 365), cos(2*pi*timestamps / 365), sin(4*pi*timestamps / 365), cos(4*pi*timestamps / 365), sin(6*pi*timestamps / 365), cos(6*pi*timestamps / 365), sin(8*pi*timestamps / 365), cos(8*pi*timestamps / 365) ];
[b,i,r,x,stats] = regress(y_detrend_ma,Xsinusoid);

ys = Xsinusoid * b;
figure; hold on; plot(y_detrend_ma); plot(ys);

y_detrended = y_detrend_ma - ys;

figure; hold on; plot(fdom(90:end)); plot(y_detrend_ma); plot(y_detrended);

hf.build_predictor_matrix(timestamps);
y = y_detrended;

[b,i,r,x,stats] = regress(y,hf.K);

ym = hf.K * b;
figure; hold on; plot(y); plot(ym);
figure; plotyy(timestamps, hf.K(:,2), timestamps, y);

% just diffs
ydiff = y_detrended(2:end) - y_detrended(1:end-1);
[b,i,r,x,stats] = regress(ydiff,hf.K);
ym = hf.K * b;
figure; hold on; plot(ydiff); plot(ym);

% short ma
lags = 30;
mashort = tsmovavg(fdom, 's', lags, 1);
figure; hold on; plot(fdom(lags/2: end)); plot(mashort(lags:end));

yma = fdom(lags/2:end-lags/2) - mashort(lags:end);
figure; hold on; plot(fdom(lags/2:end-lags/2)); plot(yma + 30);

shift = min(yma);
yma = yma - shift;

timestamps = ts(lags/2:end-lags/2,1);
hf.build_predictor_matrix(timestamps);
[b,i,r,x,stats] = regress(yma,hf.K);

ym = hf.K * b;
figure; hold on; plot(yma); plot(ym);
figure; plotyy(timestamps, hf.K(:,2), timestamps, yma);

figure; hold on; plot(ym  + shift + mashort(lags:end)); plot(fdom(lags/2:end-lags/2));
rsquare(ym  + shift + mashort(lags:end), fdom(lags/2:end-lags/2))

% gen least sq
result = olsc(yma, hf.K);
b = result.beta
ym = hf.K * b;
figure; hold on; plot(yma); plot(ym);
figure; plotyy(timestamps, hf.K(:,2), timestamps, yma);
rsquare(yma, ym)

figure; hold on; plot(timestamps,mashort(lags:end)); plot(timestamps,ym);  datetick('x');
figure; hold on; plot(timestamps, ym  + shift + mashort(lags:end)); plot(timestamps, fdom(lags/2:end-lags/2)); datetick('x');
rsquare(ym  + shift + mashort(lags:end), fdom(lags/2:end-lags/2))

% phenology
pts = [datenum('2011-10-15'); datenum('2012-10-15'); datenum('2013-10-15'); datenum('2014-10-15'); datenum('2015-10-15')];
tree = [50,50,50,50,50];
figure; hold on; plot(timestamps,mashort(lags:end)); plot(timestamps,ym); stem(pts,tree);  datetick('x');
precip_big = hf.K((hf.K(:,2) > 1000),2);
precip_big_ts = timestamps((hf.K(:,2) > 1000));
figure; hold on; plot(timestamps,mashort(lags:end)); plot(timestamps,ym); stem(pts,tree); stem(precip_big_ts, sqrt(precip_big));  datetick('x');


% no constant
K = hf.K(:,2:end);
result = olsc(yma, K);
b = result.beta
ym = K * b;
figure; hold on; plot(yma); plot(ym);
figure; plotyy(timestamps, K(:,1), timestamps, yma);
rsquare(yma, ym)

figure; hold on;
plot(fdom);
for i = 1:6
    lags = i * 10;
    mashort = tsmovavg(fdom, 's', lags, 1);
    plot(mashort(lags/2 : end));
    i
end


