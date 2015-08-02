n = 0:319;
x = cos(pi/4*n)+randn(size(n));
[pxx, w] = pmtm(x,2.5)

psdplot(pxx, w)



rng default
Fs = 1000;
t = 0:1/Fs:1-1/Fs;
c = cos(2*pi*100*t) + randn(size(t));


x = transpose(hf.usgs_timeseries.cdom)
x = x(1:300)
N = length(x);
xdft = fft(x);
xdft = xdft(1:N/2+1);
psdx = (1/(Fs*N)) * abs(xdft).^2;
psdx(2:end-1) = 2*psdx(2:end-1);
freq = 0:Fs/length(x):Fs/2;

plot(freq,10*log10(psdx))
grid on
title('Periodogram Using FFT')
xlabel('Frequency (Hz)')
ylabel('Power/Frequency (dB/Hz)')