fdom_cleaned(:,4) = fdom_cleaned(:,1) + 693959;
u = unique(fdom_cleaned(:,4));
daily_averages = zeros(2);
for i = 1:length(u)
   daily_averages(i, :) = [u(i) , mean(fdom_cleaned(fdom_cleaned(:,4) == u(i),2))];
end

X = [ones(length(daily_averages),1) sin(2*pi*daily_averages(:,1) / 365), cos(2*pi*daily_averages(:,1) / 365)];
y = daily_averages(:,2);
regress(y, X)


ym = 30.8512 + 4.8195 * sin(2*pi*daily_averages(:,1) / 365) +  0.5250 * cos(2*pi*daily_averages(:,1) / 365);
yn = y - (4.8195 *sin(2*pi*daily_averages(:,1) / 365) +  0.5250 * cos(2*pi*daily_averages(:,1) / 365));
figure; 
hold on;
plot(daily_averages(:,1), daily_averages(:,2));
plot(daily_averages(:,1), ym);
plot(daily_averages(:,1), yn);
hold off;

daily_averages(:,1)/100000 

l = length(daily_averages)-1;
X = [daily_averages(1:l,2) ones(l,1) sin(2*pi*daily_averages(1:l,1) / 365), cos(2*pi*daily_averages(1:l,1) / 365), sin(4*pi*daily_averages(1:l,1) / 365), cos(4*pi*daily_averages(1:l,1) / 365), sin(6*pi*daily_averages(1:l,1) / 365), cos(6*pi*daily_averages(1:l,1) / 365)];
y = daily_averages(2:l+1,2);


l = length(daily_averages)
X = [ones(l,1) sin(2*pi*daily_averages(1:l,1) / 365), cos(2*pi*daily_averages(1:l,1) / 365), sin(4*pi*daily_averages(1:l,1) / 365), cos(4*pi*daily_averages(1:l,1) / 365), sin(6*pi*daily_averages(1:l,1) / 365), cos(6*pi*daily_averages(1:l,1) / 365)];
y = daily_averages(1:l,2);

b = regress(y, X)

ym = X * b;
bn = b;
bn(1) = 0;
yn = y - X * bn;
figure; 
hold on;
plot(daily_averages(1:l,1), daily_averages(1:l,2));
plot(daily_averages(1:l,1), ym);
plot(daily_averages(1:l,1), yn);
datetick('x');
hold off;


figure;
plot(daily_averages(:,1), yn);
datetick('x');




timestamps = daily_averages(:,1);


