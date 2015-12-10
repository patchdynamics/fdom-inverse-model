fdom = ts(:,2);
fdom = log(fdom-14)

lags = 60;
mashort = tsmovavg(fdom, 's', lags, 1);
figure; hold on; plot(fdom(lags/2: end)); plot(mashort(lags:end));

yma = fdom(lags/2:end-lags/2) - mashort(lags:end);
figure; hold on; plot(fdom(lags/2:end-lags/2)); plot(yma + 30);

shift = min(yma);
yma = yma - shift;

timestamps = ts(lags/2:end-lags/2,1);
hf.build_predictor_matrix(timestamps);
[b,i,r,x,stats] = regress(yma,hf.K);
%result = olsc(yma, hf.K);
%b = result.beta

ym = hf.K * b;
figure; hold on; plot(yma); plot(ym);
figure; plotyy(timestamps, hf.K(:,2), timestamps, yma);

figure; hold on; plot(ym  + shift + mashort(lags:end)); plot(fdom(lags/2:end-lags/2));
rsquare(ym  + shift + mashort(lags:end), fdom(lags/2:end-lags/2))

figure; hold on; plot(ym  + shift); plot(mashort(lags:end));

r = fdom(lags/2:end-lags/2) - (ym  + shift + mashort(lags:end));
figure; plot(r);