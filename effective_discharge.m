
hf = haddam_fdom.start_usgs_timeseries;
hf.filter_discharge;
hf.filter_doc_mass_flow;

% mass flow vs. discharge

y = hf.usgs_timeseries_filtered_doc_mass_flow;
x = hf.usgs_timeseries_filtered_discharge;
X = [ones(length(x), 1) x];

[b,bint,r,rint,stats] = regress(y,X);   

doc_mass_flow = b(1) + b(2) * x;
% R2 = .975
% b = 8539.6 88.4
figure; plot(hf.usgs_timeseries_timestamps, hf.usgs_timeseries_filtered_doc_mass_flow, hf.usgs_timeseries_timestamps, doc_mass_flow);

thomp = csvread('../data/thomsponsvill_dv_1928_present.tab');
%thomp = thomp( length(thomp) - 10 * 365 : length(thomp));
% calc exceedence
thomp = sort(thomp, 'descend');
exceedence = zeros(length(thomp), 1);
for i = 1:length(thomp)
    exceedence(i) = i / (length(thomp)+1);
end

figure; semilogx(thomp, exceedence);

figure; 
[hax, ~, ~] = plotyy(thomp, exceedence, x, doc_mass_flow);
set(hax(2),'ylim',[min(doc_mass_flow) max(doc_mass_flow)]);


% plot effective discharge
discharge = transpose(linspace(min(thomp),max(thomp), 1000));
mass_flows = 8539.6 + 88.4 * discharge;
%mass_flows = b(1) + b(2) * discharge;

[thomp_unique,ia,ic] = unique(thomp,'rows');
exceedence_unique = exceedence(ia);

exceedence_interp = interp1(thomp_unique, exceedence_unique, discharge)

effective_discharge_curve = mass_flows .* exceedence_interp

figure; plot(discharge, effective_discharge_curve);

figure;
subplot(2,1,1)
[hax, ~, ~] = plotyy(thomp, exceedence, x, doc_mass_flow);
set(hax(2),'ylim',[min(doc_mass_flow) max(doc_mass_flow)]);
xlim([0 14*10^4])

subplot(2,1,2)
plot(discharge, effective_discharge_curve);
xlim([0 14*10^4])
ylabel('effective discharge curve')
xlabel('discharge')



% concentration
% there's really no relationship between discharge and [DOC] here
% R^2 < .1
y = hf.usgs_timeseries.doc_concentration;
x = hf.usgs_timeseries_filtered_discharge;
X = [ones(length(x), 1) x];

[b,bint,r,rint,stats] = regress(y,X);   

doc_conc = b(1) + b(2) * x;

