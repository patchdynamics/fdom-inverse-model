summer = month(timestamps) > 5 & month(timestamps) < 10;

figure; 
%subplot(3,1,1); 
hold on;
month = summer;
p = precip_five_day(month);
zeros = precip_five_day(month) < 100;
p(zeros) = [];
f = fdom(month);
f(zeros) = [];
plot(p,f, '*'); 
X = [ones(length(p),1) p];
b1 = olsc(f, X);
b1 = b1.beta;
y = X * b1;
plot(p, y, '+');
xlim([0 max(precip_five_day)]);
ylim([0 max(fdom)]);
hold off;
subplot(3,1,2); plot(precip_five_day(spring), fdom(spring), '*');
hold on;
X = [ones(length(precip_five_day(spring)),1) precip_five_day(spring)];
b2 = olsc(fdom(spring), X);
b2 = b2.beta;
y = X * b2;
plot(precip_five_day(spring), y);
xlim([0 max(precip_five_day)]); 
ylim([0 max(fdom)]);
hold off;
subplot(3,1,3); plot(precip_five_day(summer), fdom(summer), '*');
hold on;
X = [ones(length(precip_five_day(summer)),1) precip_five_day(summer)];
b3 = olsc(fdom(summer), X);
b3 = b3.beta;
y = X * b3;
plot(precip_five_day(summer), y);
xlim([0 max(precip_five_day)]); 
ylim([0 max(fdom)]);
hold off;