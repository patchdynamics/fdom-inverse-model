fdom
doc_mass_flow
insolation_series
temperatures
doc_export_series
snow
pdsi_series

% correct missing values
temperatures(917) = NaN;
temperatures(918) = NaN;
pdsi_series(918) = NaN;



X = [ fdom, insolation_series, temperatures, doc_export_series, pdsi_series, snow];
figure; 
[R, Pvalue] = corrplot(X, 'varNames', {'FDOM', 'Insolation', 'T', 'doc_export_series', 'PDSI', 'snow'}, 'testR', 'on')


XMassFlow = [ doc_mass_flow, insolation_series, temperatures, doc_export_series, pdsi_series, snow];
[R, Pvalue] = corrplot(XMassFlow, 'varNames', {'Mass Flow', 'Insolation', 'T', 'doc_export_series', 'PDSI', 'snow'}, 'testR', 'on')
