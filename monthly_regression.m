summer = month(timestamps) > 5 & month(timestamps) < 10;



hf.build_predictor_matrix(timestamps);
clear bb
clear yp
yp = [];
for m = 1:12
    onemonth = month(timestamps) == m;
    y = ymalog(onemonth);
    K = hf.K(onemonth,:);
    [b,i,r,x,stats] = regress(y, K);
    result = olsc(y,K);
    b = result.beta
    bb(m,:) = b;
    yn = hf.K(onemonth,:) * b;
    yp(onemonth) = yn;
    stats(1)
    %figure; 
    %hold on; 
    %plot(timestamps(onemonth), y);
    %plot(timestamps(onemonth), yn);
    %datetick('x');
end
figure; hold on; plot(timestamps, ymalog); plot(timestamps, transpose(yp));
datetick('x'); 
rsquare(ymalog, transpose(yp))
figure; plot(ymalog - transpose(yp))

figure; plot(bb(:,1));
figure;
hold on;
for m = 1:12
    plot3(1:14,bb(m,2:end),repmat(m,14,1));
end
legend('1','2','3','4','5','6','7','8','9','10','11','12');
