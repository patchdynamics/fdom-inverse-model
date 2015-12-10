ts_al = ts;

autolag = hf.num_history_days+2; %b/c it skips the first day currently
%autolag = 3;
clip = 100;
hf.build_predictor_matrix(ts_al(clip+autolag+1:end,1));
hf.K(:,end+1) = ts_al(clip+1:end-autolag,2);
[b,bi,r,x,stats_al] = regress(ts_al(clip+autolag+1:end,2), hf.K);
results_al = olsc(ts_al(clip+autolag+1:end,2), hf.K);
b= results_al.beta;

ym = hf.K * b;
y = ts_al(clip+autolag+1:end,2);
figure;
plot(r);
figure; plot(r(2:end), r(1:end-1), '*')
figure;
hold on;
plot(y);
plot(ym);

