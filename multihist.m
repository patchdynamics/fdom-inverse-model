figure;
subplot(2,2,1);
histogram(fdom(month(ts(:,1)) < 6));
subplot(2,2,2);
histogram(fdom(   (month(ts(:,1)) < 10) & (month(ts(:,1)) > 5) ));
subplot(2,2,3);
histogram(fdom(month(ts(:,1)) > 9));
subplot(2,2,4);
histogram(fdom);

fdomh = ts(:,2);
timestamps = 

figure; 
hold on;
for i = 1:12
     [N, edges] =  histcounts(fdomh(   (month(timestamps)) == i) );
     plot3(repmat(i, length(N),1), edges(1:end-1), N);
end
