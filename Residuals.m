% Residuals

hf.y = y_detrended;

hf.y = y_detrended_ma;  % also must set timestamps
hf.build_predictor_matrix(y_detrended_timestamps);

[b, bi, r] = regress(hf.y, hf.K);
figure; hold on; plot(hf.K*b); plot(hf.y); plot(r); hold off;

yr = r(2:end);
Xr = r(1:end-1);
[br,bir,rr] = regress(yr, Xr);

ystar = hf.y(2:end) - br(1) * hf.y(1:end-1);
xstar = [ones(length(hf.y)-1,1) hf.K(2:end,2:end) - br(1)*hf.K(1:end-1,2:end)];
[bstar, bistar, rstar, yuk, statsstar] = regress(ystar, xstar);

yn = xstar * bstar;
figure; hold on; plot(ystar); plot(yn); hold off;


% back it back out



hf.y = y_detrended_ma;  % also must set timestamps
hf.build_predictor_matrix(y_detrended_timestamps);

hf.y = y_interp;
timestamps = full_timestamps;
hf.build_predictor_matrix(timestamps);
Xsinusoid = [ sin(2*pi*timestamps / 365), cos(2*pi*timestamps / 365), sin(4*pi*timestamps / 365), cos(4*pi*timestamps / 365), sin(6*pi*timestamps / 365), cos(6*pi*timestamps / 365)];
hf.K = [hf.K Xsinusoid];

result = olsc(hf.y, hf.K);
result.beta

% actual y can be calc'd from these beta
yn = hf.K * result.beta;
figure; hold on; plot(hf.y); plot(yn); hold off;



yt = result.yhat + result.rho * hf.y(1:end-1);
figure; hold on; plot(hf.y(2:end)); plot(yt); hold off;


% skip the lag
yy = (hf.K(2:end,:) - result.rho * hf.K(1:end-1,:)) * result.beta;

