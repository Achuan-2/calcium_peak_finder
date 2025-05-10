% MATLAB code for two-photon calcium imaging data analysis
% This script processes dff_sig matrix containing ΔF/F data
% Each row represents a neuron and each column represents a frame (3.61 Hz)

% Parameters
framerate = 3.61; % Hz
min_peak_distance = 20; % Minimum distance between peaks (in second)

% Load data (uncomment and modify path as needed)
% load('path_to_your_data.mat'); % Should contain dff_sig matrix

% Check if dff_sig exists in workspace
if ~exist('dff_sig', 'var')
    % 捕获并显示错误信息
    errordlg("不存在dff_sig变量！", 'Error');
end

% Get data dimensions
[num_neurons, num_frames] = size(dff_sig);
time_vector = (1:num_frames) / framerate; % Time in seconds

% Create directory structure for saving results
analysis_dir = 'analysis';
peak_detection_dir = fullfile(analysis_dir, 'signle_neuron_peak_Detection');

if ~exist(analysis_dir, 'dir')
    mkdir(analysis_dir);
end
if ~exist(peak_detection_dir, 'dir')
    mkdir(peak_detection_dir);
end

% Initialize results structure
results = struct();
for n = 1:num_neurons
    results(n).neuron_id = n;
    results(n).peak_indices = [];
    results(n).peak_values = [];
    results(n).fwhm = [];
    results(n).calcium_event_frequency = 0;
    results(n).inter_event_intervals = [];
end

% Process each neuron
for n = 1:num_neurons
    % Get current neuron's dF/F trace
    trace = dff_sig(n, :);
    
    % Improved peak detection according to requirements
    % Calculate properties
    baseline = prctile(trace, 30);
    baseline_values = trace(trace <= baseline);
    base_std = std(baseline_values); % Standard deviation of baseline
    signal_max = max(trace);
    signal_min = min(trace);

    
    % Find peaks with parameters that adapt to the signal
    [peak_values, peak_indices, peak_widths, peak_prominences] = findpeaks(trace, ...
        'MinPeakHeight', 0.5, ...
        'MinPeakProminenc',0.5, ...
        'MinPeakDistance', min_peak_distance*framerate);

    
    % Store peak info
    results(n).peak_indices = peak_indices;
    results(n).peak_values = peak_values;
    results(n).peak_widths = peak_widths;
    results(n).peak_prominences = peak_prominences;
    results(n).num_spikes = length(peak_indices);
    
    % Calculate calcium event frequency (events/minute)
    recording_duration_minutes = num_frames / framerate / 60;
    results(n).calcium_event_frequency = results(n).num_spikes / recording_duration_minutes;
    
    % Calculate inter-event intervals (in seconds)
    if length(peak_indices) > 1
        results(n).inter_event_intervals = diff(peak_indices) / framerate;
    end
    
    % Calculate FWHM for each peak
    for p = 1:length(peak_indices)
        peak_idx = peak_indices(p);
        peak_val = peak_values(p);
        half_max = (peak_val - baseline) / 2 + baseline;
        
        % Find left crossing
        left_idx = peak_idx;
        while left_idx > 1 && trace(left_idx) > half_max
            left_idx = left_idx - 1;
        end
        
        % Find right crossing
        right_idx = peak_idx;
        while right_idx < num_frames && trace(right_idx) > half_max
            right_idx = right_idx + 1;
        end
        
        % Interpolate to find more accurate crossing points
        if left_idx > 1 && right_idx < num_frames
            % Left crossing
            x1 = left_idx - 1;
            x2 = left_idx;
            y1 = trace(x1);
            y2 = trace(x2);
            left_cross = x1 + (half_max - y1) * (x2 - x1) / (y2 - y1);
            
            % Right crossing
            x1 = right_idx - 1;
            x2 = right_idx;
            y1 = trace(x1);
            y2 = trace(x2);
            right_cross = x1 + (half_max - y1) * (x2 - x1) / (y2 - y1);
            
            % Calculate FWHM in seconds
            fwhm_frames = right_cross - left_cross;
            fwhm_seconds = fwhm_frames / framerate;
            results(n).fwhm(p) = fwhm_seconds;
        else
            results(n).fwhm(p) = NaN;
        end
    end
    
    % Plot and save the neuron's trace and detected peaks as individual image
    fig = figure('Visible', 'off', 'Position', [100, 100, 2000, 400]);
    plot(time_vector, trace, 'b-', 'LineWidth', 1.5);
    hold on;
    
    if ~isempty(peak_indices)
        plot(time_vector(peak_indices), peak_values, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        
        % Highlight FWHM regions
        for p = 1:length(peak_indices)
            if ~isnan(results(n).fwhm(p))
                peak_idx = peak_indices(p);
                fwhm_seconds = results(n).fwhm(p);
                half_max = (peak_values(p) - baseline) / 2 + baseline;
                
                % Calculate time points for FWHM
                center_time = time_vector(peak_idx);
                fwhm_start = center_time - fwhm_seconds/2;
                fwhm_end = center_time + fwhm_seconds/2;
                

            end
        end
    end
    
    grid on;
    title(['Neuron #', num2str(n), ' - ', num2str(results(n).num_spikes), ...
           ' spikes, Freq: ', num2str(results(n).calcium_event_frequency, '%.2f'), ' events/min'], ...
           'FontSize', 12);
    xlabel('Time (s)', 'FontSize', 12);
    ylabel('\DeltaF/F', 'FontSize', 12);
    

    % Add legend
    if ~isempty(peak_indices)
        legend('Calcium Signal', 'Detected Peaks',  'Location', 'best');
    else
        legend('Calcium Signal',  'Location', 'best');
    end
    
    % Save the figure for this neuron
    filename = fullfile(peak_detection_dir, sprintf('Neuron_%d_peaks.png', n));
    saveas(fig, filename);
    close(fig);
end

% Create summary figure with statistics and save it
fig_summary = figure('Visible', 'on', 'Position', [100, 100, 1200, 800]);

% 1. Plot number of spikes per neuron
subplot(2, 3, 1);
bar([results.num_spikes]);
title('Number of Calcium Events per Neuron');
xlabel('Neuron ID');
ylabel('Count');
grid on;

% 2. Plot calcium event frequency per neuron
subplot(2, 3, 2);
bar([results.calcium_event_frequency]);
title('Calcium Event Frequency');
xlabel('Neuron ID');
ylabel('Events/minute');
grid on;

% 3. Box plot of inter-event intervals
all_intervals = [];
for n = 1:num_neurons
    all_intervals = [all_intervals; results(n).inter_event_intervals(:)];
end
subplot(2, 3, 3);
if ~isempty(all_intervals)
    boxplot(all_intervals);
    title('Distribution of Inter-event Intervals');
    ylabel('Time (s)');
    grid on;
else
    text(0.5, 0.5, 'Not enough events to calculate intervals', 'HorizontalAlignment', 'center');
    axis off;
end

% 4. FWHM distribution
all_fwhm = [];
for n = 1:num_neurons
    all_fwhm = [all_fwhm, results(n).fwhm];
end
subplot(2, 3, 4);
if ~isempty(all_fwhm)
    histogram(all_fwhm, 20);
    title('FWHM Distribution');
    xlabel('Duration (s)');
    ylabel('Count');
    grid on;
else
    text(0.5, 0.5, 'No FWHM data available', 'HorizontalAlignment', 'center');
    axis off;
end

% 5. Average FWHM per neuron
subplot(2, 3, 5);
mean_fwhm = zeros(1, num_neurons);
for n = 1:num_neurons
    if ~isempty(results(n).fwhm)
        mean_fwhm(n) = mean(results(n).fwhm, 'omitnan');
    else
        mean_fwhm(n) = 0;
    end
end
bar(mean_fwhm);
title('Average Calcium Response Duration (FWHM)');
xlabel('Neuron ID');
ylabel('Duration (s)');
grid on;

% 6. Peak values distribution
subplot(2, 3, 6);
all_peaks = [];
for n = 1:num_neurons
    all_peaks = [all_peaks, results(n).peak_values];
end
if ~isempty(all_peaks)
    histogram(all_peaks, 20);
    title('Peak Values Distribution');
    xlabel('\DeltaF/F');
    ylabel('Count');
    grid on;
else
    text(0.5, 0.5, 'No peak data available', 'HorizontalAlignment', 'center');
    axis off;
end

% Save the summary figure
saveas(fig_summary, fullfile(analysis_dir, 'Summary_Statistics.png'));

% Print summary statistics to console
fprintf('===== CALCIUM IMAGING ANALYSIS SUMMARY =====\n');
fprintf('Total neurons analyzed: %d\n', num_neurons);
for n = 1:num_neurons
    fprintf('\nNEURON #%d:\n', n);
    fprintf('  Number of calcium events: %d\n', results(n).num_spikes);
    fprintf('  Calcium event frequency: %.2f events/min\n', results(n).calcium_event_frequency);
    if ~isempty(results(n).inter_event_intervals)
        fprintf('  Mean inter-event interval: %.2f s\n', mean(results(n).inter_event_intervals));
    else
        fprintf('  Mean inter-event interval: N/A (too few events)\n');
    end
    if ~isempty(results(n).fwhm)
        fprintf('  Mean calcium response duration (FWHM): %.2f s\n', mean(results(n).fwhm, 'omitnan'));
    else
        fprintf('  Mean calcium response duration (FWHM): N/A\n');
    end
    if ~isempty(results(n).peak_values)
        fprintf('  Mean peak amplitude: %.2f ΔF/F\n', mean(results(n).peak_values));
        fprintf('  Max peak amplitude: %.2f ΔF/F\n', max(results(n).peak_values));
    else
        fprintf('  Mean peak amplitude: N/A\n');
        fprintf('  Max peak amplitude: N/A\n');
    end
end

% Create table with basic statistics
stats_table = table((1:num_neurons)', ...
                   [results.num_spikes]', ...
                   [results.calcium_event_frequency]', ...
                   mean_fwhm', ...
                   'VariableNames', {'NeuronID', 'NumEvents', 'EventFreq_perMin', 'MeanFWHM_s'});

% Display table
disp(stats_table);

% Export table
writetable(stats_table, fullfile(analysis_dir, 'calcium_stats.csv'));

% Create neuron data structure with traces and detected peaks 
neuron_data = struct();
for n = 1:num_neurons
    neuron_name = sprintf('neuron_%d', n);
    neuron_data.(neuron_name).trace = dff_sig(n, :);
    neuron_data.(neuron_name).time = time_vector;
    neuron_data.(neuron_name).peak_indices = results(n).peak_indices;
    neuron_data.(neuron_name).peak_values = results(n).peak_values;
    neuron_data.(neuron_name).fwhm = results(n).fwhm;
    if isfield(results(n), 'peak_prominences')
        neuron_data.(neuron_name).peak_prominences = results(n).peak_prominences;
    end
end

% --- MERGED MAT FILE SOLUTION ---

analysis_date = datestr(now); % Date analysis was performed

% Save the merged data into a single MAT file
save(fullfile(analysis_dir, 'calcium_analysis_result.mat'), 'results','neuron_data',"time_vector",'framerate','analysis_date');

% Display confirmation message
fprintf('\nAll analysis data saved to a single file: %s\n', ...
    fullfile(analysis_dir, 'calcium_analysis_complete.mat'));