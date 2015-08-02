figure;
plot(f(1:10)*365*24,2*abs(Y(1:10)), 'o') 
title('Single-Sided Amplitude Spectrum of y(t)')
xlabel('Cycles Per Year')
ylabel('|Y(f)|')

y = hf.usgs_timeseries.cdom;
L = length(y);
NFFT = 2^nextpow2(L);
Y = fft(y, L);


y1 = ifft(Y(1:30),L,'symmetric');
y1 = ifft(Y(1:2),L, 'symmetric');
norm(y-y1)
figure; plot(y1);


y1 = ifft(Y(1:4),L, 'symmetric');
figure; plotyy(1:L, y, 1:L, y1)


% haddam analysis - something still wrong here!
L = 1000; y = hf.usgs_timeseries.cdom(1:L); q = hf.usgs_timeseries.discharge(1:L); q(isnan(q))=0;  Y = fft(y); Q = fft(q);
Ypl = Y; Ypl(1) = 0; magY = abs(Y); magQ = abs(Q); magYpl = magY; magYpl(1) = 0; magQpl = magQ; magQpl(1) = 0; 
figure; Lpl=1:200; plotyy(Lpl, magYpl(Lpl), Lpl, magQpl(Lpl)); legend('Discharge', 'CDOM');


% some problems computing frequency values for plotting...
% wrong! figure; lpl = 500; plot( F(1:lpl), abs(Q(1:lpl))); xlabel('Cycles Per Minute')
% don't compute mags on the subarray, has to be on the original.


x = zeros(10,1);
x(1) = 1;
x(10) = 0;
X = fft(x);

figure;
hold on;
len = length(x);
for i=1:length(X)
    XX = zeros(length(X), 1);
    XX(i) = X(i);

    plot(ifft(XX(1:i), len, 'symmetric'))
end


L = 89569 - 169;  % for tidal f is fourier freq
L = 89569 - 20;
y = hf.usgs_timeseries.cdom(1:L);
Y = fft(y);
Yp = Y;  Yp(1) = 0;
magYp = abs(Yp);

figure; Lp = L/2; plot(F(min:Lp), magYp(min:Lp), '*');
xlim([0 0.05]);

figure; Lp = L/2; plot((min:Lp), magYp(min:Lp), '*');
xlim([0 1000]);

Ym = Y;
Ym(936) = 0;
%Ym(L-936)=0;
y1 = ifft(Ym,L,'symmetric');
norm(y-y1)
figure; plotyy((1:L), y, (1:L), y1);

Yb = Y;
wall = 400;
Yb(1:wall) = 0;
Yb(end-wall:end) = 0;
yb = ifft(Yb,L,'symmetric');
figure; Lp = 500; plotyy((1:Lp)*.25, y(1:Lp), (1:Lp)*.25, yb(1:Lp));

Ybm = Yb;
Ybm(936) = 0;
Ybm(937) = 0;
Ybm(938) = 0;
Ybm(900:1000) = 0;


%Ybm(end-936) = 0;
ybm = ifft(Ybm,L,'symmetric');
%figure; plot((1:L), ybm);
figure; Lp = 2500; plotyy((1:Lp)*.25, yb(1:Lp), (1:Lp)*.25, ybm(1:Lp));

YY = fft(ybm);
YYp = YY;  YYp(1) = 0;
magYYp = abs(YYp);
figure; Lp = L/2; plot((min:Lp), magYYp(min:Lp), '*');
xlim([0 1000]);



% discharge
L = 89569 - 20;

Fs = 4; % 4/hr
F = (0:1/L:1-1/L)*Fs;

y = hf.usgs_timeseries.discharge;
% deal with empty data
tf = isnan(y);
ix = 1:numel(y);
y(tf) = interp1(ix(~tf),y(~tf),ix(tf));
discharge = y;

Y = fft(y(1:L));
Yp = Y;  Yp(1) = 0;
magYp = abs(Yp);
figure; Lp=100; plot(magYp(1:Lp));

min = 40;
figure; Lp = L/2; plot(F(min:Lp), magYp(min:Lp), '*');
xlim([0 0.05]);


% check for gaps
timestamps = hf.usgs_timeseries_timestamps;
step = timestamps(2) - timestamps(1);

for i = 2:L
    diff = timestamps(2) - timestamps(1);
    if diff ~= step
        diff
    end
end




% plotting
min = 10000;
max = min + 4 * 25 * 2;
figure; plot( (1:max) * .25, hf.usgs_timeseries.cdom(1:max))
figure; plot( (min:max) * .25, hf.usgs_timeseries.discharge(min:max))
figure; plotyy( (min:max) * .25, hf.usgs_timeseries.discharge(min:max), (min:max) * .25, hf.usgs_timeseries.cdom(min:max)); legend('discharge', 'cdom');
figure; plotyy( (min:max) * .25 / 24, hf.usgs_timeseries.discharge(min:max), (min:max) * .25 / 24, hf.usgs_timeseries.cdom(min:max)); legend('discharge', 'cdom');


designfilt('lowpassiir', 'FilterOrder', 1)
lpFilt = designfilt('lowpassiir', 'FilterOrder', 1, 'StopbandFrequency', .999, 'StopbandAttenuation', 100);
fvtool(lpFilt);
dataOut = filtfilt(lpFilt,y);

passband = 0.01;
band = 0.001;
lpFilt = designfilt('lowpassfir','PassbandFrequency',passband, ...
         'StopbandFrequency',passband+0.001,'PassbandRipple',0.001, ...
         'StopbandAttenuation',100,'DesignMethod','kaiserwin');
%fvtool(lpFilt);
dataOut = filtfilt(lpFilt,y);
figure; plot( (min:max) * .25, dataOut(min:max))
figure; plotyy( (min:max) * .25, y(min:max), (min:max) * .25, dataOut(min:max)); legend('original', 'filtered');

Y = fft(dataOut);
Yp = Y;  Yp(1) = 0;
magYp = abs(Yp);
figure; plot(magYp);
figure; Lp = 300; plot(.25*(1:Lp), magYp(1:Lp), '*');

figure; plotyy( F, y(1:L), (1:L) * .25, dataOut(1:L)); legend('original', 'filtered');



L = 89569 - 169;  % for tidal f is fourier freq
%L = 89569 - 20;
y = hf.usgs_timeseries.conductance(1:L);

tf = isnan(y);
ix = 1:numel(y);
y(tf) = interp1(ix(~tf),y(~tf),ix(tf));

Y = fft(y);
Yp = Y;  Yp(1) = 0;
magYp = abs(Yp);

figure; Lp = L/2; plot(F(min:Lp), magYp(min:Lp), '*');
xlim([0 0.2]);

figure; Lp = L/2; plot((min:Lp), magYp(min:Lp), '*');
xlim([0 5000]);


% cross correllation
[XCF,lags,bounds] = crosscorr(discharge, hf.usgs_timeseries.cdom,400)
figure; plot(lags, XCF, '*')


min = 1; max = 40000; figure; plotyy((min:max), discharge(min:max), (min:max), hf.usgs_timeseries.cdom(min:max));

% this one is close
min = 25000; max = 26400; figure; plotyy((min:max), hf.usgs_timeseries_filtered_discharge(min:max), (min:max), hf.usgs_timeseries.cdom(min:max));

% this is the norm, much more delayed
min = 14000; max = 17000; figure; plotyy((min:max), hf.usgs_timeseries_filtered_discharge(min:max), (min:max), hf.usgs_timeseries.cdom(min:max));


[XCF,lags,bounds] = crosscorr(hf.usgs_timeseries_filtered_discharge(min:max), hf.usgs_timeseries.cdom(min:max),800)

[XCF,lags,bounds] = crosscorr(discharge(min:max), hf.usgs_timeseries.cdom(min:max),800)
figure; plot(lags/4/24, XCF, '*')



modulated = cos(2 * pi * signal4);
figure; plot(modulated(1:100));

modulated = cos(2 * pi * signal4);
hplayer = audioplayer(modulated, Fs/5);
play(hplayer)
audiowrite('fdom-at-haddam-fm.wav', modulated, Fs/5)
figure;  plot(modulated(1:300), '-m')

modulated = cos(2 * pi * signal);
hplayer = audioplayer(modulated, Fs/5);
play(hplayer)

davg = abs(tsmovavg(discharge,'s',48,1));
figure; plot(log(davg))

dmeaned = davg - mean(discharge);

sig =  log10(abs(log10(davg)));
figure; plot(sig)
modulated = cos(2 * pi * sig);
figure; plot(modulated(1:600))

m = cos(2 * pi * (sqrt(sig) + 50000));  % something wrong with yonder f
p = audioplayer(m, Fs/5);
play(p)

audiowrite('discharge-at-haddam-fm.wav', modulated, Fs/5)

mod_fdom = cos(2 * pi * (signal4 * 2) );
mod_discharge = cos(2 * pi * (sig / 5) );
combined = mod_fdom + mod_discharge;
p = audioplayer(combined, Fs/8);
play(p)

p = audioplayer(cos(2 * pi * 440 / (1:4000) ), Fs);  % pure freq?
play(p)


J = 500;
figure; plotyy((1:J), mod_fdom(1:J), (1:J), mod_discharge(1:J))

figure; plotyy((1:J), combined(1:J), (1:J), mod_discharge(1:J))

p = audioplayer(combined, Fs/5);
play(p)

