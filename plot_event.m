function plot_event(i, EventIndices, hf)

    FlowStartIdx = EventIndices(i, 1);
    FlowEndIdx = EventIndices(i, 2);
    PrecipitationStartIdx = EventIndices(i, 3);
    PrecipitationEndIdx = EventIndices(i, 4);
    EventIdx = EventIndices(i, 5);

    start =  min([FlowStartIdx PrecipitationStartIdx]) - 200;
    domain = start:FlowEndIdx;
    figure;
    subplot(2,1,1);
    plot(hf.usgs_timeseries_timestamps(domain), hf.usgs_timeseries_filtered_doc_mass_flow_eq2(domain));
    datetick('x');
    line([hf.usgs_timeseries_timestamps(FlowStartIdx), hf.usgs_timeseries_timestamps(FlowStartIdx)], [0, 10000000], 'Color', 'm')
    line([hf.usgs_timeseries_timestamps(FlowEndIdx), hf.usgs_timeseries_timestamps(FlowEndIdx)], [0, 10000000], 'Color', 'm')
    line([hf.usgs_timeseries_timestamps(PrecipitationStartIdx), hf.usgs_timeseries_timestamps(PrecipitationStartIdx)], [0, 10000000], 'Color', 'k')
    line([hf.usgs_timeseries_timestamps(PrecipitationEndIdx), hf.usgs_timeseries_timestamps(PrecipitationEndIdx)], [0, 10000000], 'Color', 'k')
    line([hf.usgs_timeseries_timestamps(EventIdx), hf.usgs_timeseries_timestamps(EventIdx)], [0, 10000000], 'Color', 'g')

    subplot(2,1,2);
    stem(hf.precipitation_timestamps, hf.precipitation_data.total_precipitation);
    datetick('x');
    xlim([hf.usgs_timeseries_timestamps(start), hf.usgs_timeseries_timestamps(FlowEndIdx)])
    datetick('x');

end