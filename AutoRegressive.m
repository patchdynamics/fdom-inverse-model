% autoregression model

y = y_detrended(2:end);

X = [ ones(length(y), 1) y_detrended(1:end-1)];
b = regress(y, X);

yn = X * b;

figure;
hold on;
plot(y, '*');
plot(yn, '*');
hold off;

r = y - yn;
figure; plot(r);
rsquare(y, yn)