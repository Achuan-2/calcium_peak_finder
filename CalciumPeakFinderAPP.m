classdef CalciumPeakFinderAPP < matlab.apps.AppBase
    
    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        FileOperationsPanel      matlab.ui.container.Panel
        FramerateHzLabel         matlab.ui.control.Label
        FramerateEditField       matlab.ui.control.NumericEditField
        LoadDataButton           matlab.ui.control.Button
        RunAnalysisButton        matlab.ui.control.Button
        NeuronDisplayFilteringPanel matlab.ui.container.Panel
        SelectNeuronLabel        matlab.ui.control.Label
        NeuronDropDown           matlab.ui.control.DropDown
        PreviousNeuronButton     matlab.ui.control.Button
        NextNeuronButton         matlab.ui.control.Button
        AddPeakButtonClickPlotButton matlab.ui.control.Button
        DeletePeakClickPeakButton matlab.ui.control.Button
        SaveResultsButton        matlab.ui.control.Button
        PeakDetectionParametersPanel matlab.ui.container.Panel
        MinPeakHeightLabel       matlab.ui.control.Label
        MinPeakHeightEditField   matlab.ui.control.NumericEditField
        MinPeakProminenceLabel   matlab.ui.control.Label
        MinPeakProminenceEditField matlab.ui.control.NumericEditField
        MinPeakDistanceLabel     matlab.ui.control.Label
        MinPeakDistanceEditField matlab.ui.control.NumericEditField
        UIAxes                   matlab.ui.control.UIAxes
    end
    
    % Properties that store app data
    properties (Access = public)
        dff_sig                  % Loaded dF/F data
        time_vector              % Time vector for plotting
        framerate = 3.61         % Default framerate, updated from UI
        results                  % Structure to store analysis results
        neuron_data              % Detailed data per neuron
        current_neuron_id = 1    % ID of the currently displayed neuron
        min_peak_height = 0.5    % Minimum peak height for findpeaks
        min_peak_prominence = 0.5 % Minimum peak prominence for findpeaks
        min_peak_distance_sec = 20 % Min peak distance in seconds
        isAddPeakMode = false    % Flag for add peak mode
        isDeletePeakMode = false % Flag for delete peak mode
        isPanning = false        % Flag for panning mode
        panStartPoint            % Starting mouse position for panning
        currentPlotHandles       % Handles to plotted objects
        crosshairHandles         % Handles for crosshair lines and marker
    end
    
    methods (Access = private)
        % Setup mouse scroll wheel zoom
        function setupScrollWheelZoom(app)
            app.UIFigure.WindowScrollWheelFcn = @(~,event)scrollWheelCallback(app, event);
        end
        
        % Mouse scroll wheel callback
        function scrollWheelCallback(app, event)
            if isempty(app.dff_sig) || ~isgraphics(app.UIAxes)
                return;
            end
            currentPoint = app.UIAxes.CurrentPoint;
            cursorX = currentPoint(1,1);
            cursorY = currentPoint(1,2);
            curXLim = app.UIAxes.XLim;
            curYLim = app.UIAxes.YLim;
            xRatio = (cursorX - curXLim(1)) / (curXLim(2) - curXLim(1));
            yRatio = (cursorY - curYLim(1)) / (curYLim(2) - curYLim(1));
            if xRatio < 0 || xRatio > 1 || yRatio < 0 || yRatio > 1
                xRatio = 0.5;
                yRatio = 0.5;
            end
            zoomFactor = 0.8^(-event.VerticalScrollCount);
            newXLim = [cursorX - (cursorX - curXLim(1)) * zoomFactor, ...
                cursorX + (curXLim(2) - cursorX) * zoomFactor];
            newYLim = [cursorY - (cursorY - curYLim(1)) * zoomFactor, ...
                cursorY + (curYLim(2) - cursorY) * zoomFactor];
            app.UIAxes.XLim = newXLim;
            app.UIAxes.YLim = newYLim;
        end
        
        % Start panning
        function startPanning(app, src, event)
            if app.isAddPeakMode || app.isDeletePeakMode || isempty(app.dff_sig)
                return;
            end
            currentPoint = app.UIAxes.CurrentPoint;
            mouse_x = currentPoint(1,1);
            x_limits = app.UIAxes.XLim;
            if mouse_x >= x_limits(1) && mouse_x <= x_limits(2)
                app.isPanning = true;
                app.panStartPoint = currentPoint(1,1);
                app.UIFigure.WindowButtonMotionFcn = @(src,evt)panAxes(app, src, evt);
                app.UIFigure.WindowButtonUpFcn = @(src,evt)stopPanning(app, src, evt);
            end
        end
        
        % Pan axes during mouse drag
        function panAxes(app, src, event)
            if ~app.isPanning
                return;
            end
            % currentPoint = app.UIAxes.CurrentPoint;
            % mouse_x = currentPoint(1,1);
            % delta_x = app.panStartPoint - mouse_x;
            % curXLim = app.UIAxes.XLim;
            % newXLim = curXLim + delta_x;
            % min_time = min(app.time_vector);
            % max_time = max(app.time_vector);
            % if newXLim(1) < min_time
            %     newXLim = [min_time, min_time + (curXLim(2) - curXLim(1))];
            % elseif newXLim(2) > max_time
            %     newXLim = [max_time - (curXLim(2) - curXLim(1)), max_time];
            % end
            % app.UIAxes.XLim = newXLim;
            % app.panStartPoint = mouse_x;
        end
        
        % Stop panning
        function stopPanning(app, src, event)
            app.isPanning = false;
            app.UIFigure.WindowButtonMotionFcn = '';
            app.UIFigure.WindowButtonUpFcn = '';
        end
        
        % Reset interaction modes
        function resetInteractionModes(app)
            app.isAddPeakMode = false;
            app.isDeletePeakMode = false;
            app.isPanning = false;
            if isfield(app.UIAxes, 'ButtonDownFcn')
                app.UIAxes.ButtonDownFcn = '';
            end
            if ~isempty(app.currentPlotHandles) && isfield(app.currentPlotHandles, 'peaks') && ~isempty(app.currentPlotHandles.peaks) && isvalid(app.currentPlotHandles.peaks)
                app.currentPlotHandles.peaks.ButtonDownFcn = '';
            end
            app.UIFigure.WindowButtonMotionFcn = '';
            app.UIFigure.WindowKeyPressFcn = '';
            app.UIFigure.WindowButtonUpFcn = '';
            app.AddPeakButtonClickPlotButton.BackgroundColor = [0.94 0.94 0.94];
            app.DeletePeakClickPeakButton.BackgroundColor = [0.94 0.94 0.94];
            if isfield(app.crosshairHandles, 'vline') && isvalid(app.crosshairHandles.vline)
                delete(app.crosshairHandles.vline);
            end
            if isfield(app.crosshairHandles, 'hline') && isvalid(app.crosshairHandles.hline)
                delete(app.crosshairHandles.hline);
            end
            if isfield(app.crosshairHandles, 'marker') && isvalid(app.crosshairHandles.marker)
                delete(app.crosshairHandles.marker);
            end
            app.crosshairHandles = struct();
            app.UIAxes.ButtonDownFcn = @(src,evt)startPanning(app, src, evt);
            setupScrollWheelZoom(app);
        end
        
        % Update plot display
        function UpdatePlot(app)
            if isempty(app.dff_sig) || isempty(app.results) || app.current_neuron_id > length(app.results)
                cla(app.UIAxes);
                title(app.UIAxes, 'No data or neuron selected for plotting.');
                xlabel(app.UIAxes, 'Time (s)');
                ylabel(app.UIAxes, '\DeltaF/F');
                app.currentPlotHandles = [];
                app.crosshairHandles = struct();
                return;
            end
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            neuron_id = app.current_neuron_id;
            trace = app.dff_sig(neuron_id, :);
            app.currentPlotHandles.trace = plot(app.UIAxes, app.time_vector, trace, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Calcium Signal');
            app.UIAxes.XLim = [min(app.time_vector) max(app.time_vector)];
            y_min = min(trace) - 0.1 * (max(trace) - min(trace));
            y_max = max(trace) + 0.1 * (max(trace) - min(trace));
            app.UIAxes.YLim = [y_min y_max];
            peak_indices = app.results(neuron_id).peak_indices;
            peak_values = app.results(neuron_id).peak_values;
            plotTitle = sprintf('Neuron %d - %d spikes, Freq: %.2f ev/min', ...
                neuron_id, app.results(neuron_id).num_spikes, app.results(neuron_id).calcium_event_frequency);
            if ~isempty(peak_indices)
                app.currentPlotHandles.peaks = scatter(app.UIAxes, app.time_vector(peak_indices), peak_values, ...
                    'ro', 'MarkerFaceColor', 'r', 'DisplayName', 'Detected Peaks', 'SizeData', 60);
            else
                app.currentPlotHandles.peaks = [];
            end
            if app.isAddPeakMode
                app.UIFigure.WindowButtonMotionFcn = @(src,event)MouseMoveInAxes(app, src, event);
                app.UIFigure.WindowKeyPressFcn = @(src,event)KeyPressInAxes(app, src, event);
                plotTitle = [plotTitle, ' (ADD MODE: Press Enter to Add Peak)'];
            elseif app.isDeletePeakMode
                app.UIFigure.WindowButtonMotionFcn = @(src,event)MouseMoveInAxes(app, src, event);
                app.UIFigure.WindowKeyPressFcn = @(src,event)KeyPressInAxes(app, src, event);
                plotTitle = [plotTitle, ' (DELETE MODE: Press Enter to Delete Nearest Peak)'];
            else
                app.UIFigure.WindowButtonMotionFcn = '';
                app.UIFigure.WindowKeyPressFcn = '';
            end
            title(app.UIAxes, plotTitle);
            xlabel(app.UIAxes, 'Time (s)');
            ylabel(app.UIAxes, '\DeltaF/F');
            grid(app.UIAxes, 'on');
            hold(app.UIAxes, 'off');
        end
        
        % Mouse move callback for crosshairs
        function MouseMoveInAxes(app, src, event)
            currentPoint = app.UIAxes.CurrentPoint;
            mouse_x = currentPoint(1,1);
            mouse_y = currentPoint(1,2);
            x_limits = app.UIAxes.XLim;
            y_limits = app.UIAxes.YLim;
            if mouse_x < x_limits(1) || mouse_x > x_limits(2) || ...
                    mouse_y < y_limits(1) || mouse_y > y_limits(2)
                if isfield(app.crosshairHandles, 'vline') && isvalid(app.crosshairHandles.vline)
                    delete(app.crosshairHandles.vline);
                end
                if isfield(app.crosshairHandles, 'hline') && isvalid(app.crosshairHandles.hline)
                    delete(app.crosshairHandles.hline);
                end
                if isfield(app.crosshairHandles, 'marker') && ~isempty(app.crosshairHandles.marker) && isvalid(app.crosshairHandles.marker)
                    delete(app.crosshairHandles.marker);
                end
                app.crosshairHandles = struct();
                return;
            end
            if app.isDeletePeakMode
                peak_indices = app.results(app.current_neuron_id).peak_indices;
                if isempty(peak_indices)
                    if isfield(app.crosshairHandles, 'marker') && ~isempty(app.crosshairHandles.marker) && isvalid(app.crosshairHandles.marker)
                        delete(app.crosshairHandles.marker);
                        app.crosshairHandles.marker = [];
                    end
                    return;
                end
                peak_times = app.time_vector(peak_indices);
                peak_values = app.results(app.current_neuron_id).peak_values;
                dist_sq = (peak_times - mouse_x).^2 + (peak_values - mouse_y).^2;
                [~, closest_peak_idx] = min(dist_sq);
                nearest_time = peak_times(closest_peak_idx);
                nearest_value = peak_values(closest_peak_idx);
                marker_color = [1 0.5 0];
            else
                [~, nearest_idx] = min(abs(app.time_vector - mouse_x));
                nearest_time = app.time_vector(nearest_idx);
                nearest_value = app.dff_sig(app.current_neuron_id, nearest_idx);
                marker_color = 'g';
            end
            if isfield(app.crosshairHandles, 'vline') && isvalid(app.crosshairHandles.vline)
                app.crosshairHandles.vline.XData = [nearest_time nearest_time];
            else
                hold(app.UIAxes, 'on');
                app.crosshairHandles.vline = plot(app.UIAxes, [nearest_time nearest_time], y_limits, 'k--', 'HandleVisibility', 'off');
                hold(app.UIAxes, 'off');
            end
            if isfield(app.crosshairHandles, 'hline') && isvalid(app.crosshairHandles.hline)
                app.crosshairHandles.hline.YData = [nearest_value nearest_value];
            else
                hold(app.UIAxes, 'on');
                app.crosshairHandles.hline = plot(app.UIAxes, x_limits, [nearest_value nearest_value], 'k--', 'HandleVisibility', 'off');
                hold(app.UIAxes, 'off');
            end
            if isfield(app.crosshairHandles, 'marker') && isvalid(app.crosshairHandles.marker)
                app.crosshairHandles.marker.XData = nearest_time;
                app.crosshairHandles.marker.YData = nearest_value;
                app.crosshairHandles.marker.MarkerEdgeColor = marker_color;
                app.crosshairHandles.marker.MarkerFaceColor = marker_color;
            else
                hold(app.UIAxes, 'on');
                app.crosshairHandles.marker = scatter(app.UIAxes, nearest_time, nearest_value, 50, ...
                    'Marker', 'o', 'MarkerEdgeColor', marker_color, 'MarkerFaceColor', marker_color, 'HandleVisibility', 'off');
                hold(app.UIAxes, 'off');
            end
        end
        
        % Key press callback
        function KeyPressInAxes(app, src, event)
            if ~app.isAddPeakMode && ~app.isDeletePeakMode
                return;
            end
            if strcmp(event.Key, 'return')
                currentPoint = app.UIAxes.CurrentPoint;
                mouse_x = currentPoint(1,1);
                mouse_y = currentPoint(1,2);
                x_limits = app.UIAxes.XLim;
                y_limits = app.UIAxes.YLim;
                if app.isAddPeakMode
                    AddPeak(app, mouse_x);
                elseif app.isDeletePeakMode
                    DeletePeak(app, mouse_x, mouse_y);
                end
            end
        end
        
        % Add a peak
        function AddPeak(app, mouse_x)
            if isempty(app.dff_sig) || app.current_neuron_id > size(app.dff_sig,1)
                return;
            end
            [~, new_peak_idx] = min(abs(app.time_vector - mouse_x));
            new_peak_val = app.dff_sig(app.current_neuron_id, new_peak_idx);
            neuron_name_str = sprintf('neuron_%d', app.current_neuron_id);
            current_peaks_idx = app.results(app.current_neuron_id).peak_indices;
            current_peaks_val = app.results(app.current_neuron_id).peak_values;
            if ~ismember(new_peak_idx, current_peaks_idx)
                [sorted_indices, sort_order] = sort([current_peaks_idx, new_peak_idx]);
                app.results(app.current_neuron_id).peak_indices = sorted_indices;
                combined_values = [current_peaks_val, new_peak_val];
                app.results(app.current_neuron_id).peak_values = combined_values(sort_order);
                app.neuron_data.(neuron_name_str).peak_indices = app.results(app.current_neuron_id).peak_indices;
                app.neuron_data.(neuron_name_str).peak_values = app.results(app.current_neuron_id).peak_values;
                if isfield(app.results(app.current_neuron_id), 'fwhm')
                    fwhm_values = app.results(app.current_neuron_id).fwhm;
                    new_fwhm = [fwhm_values, NaN];
                    app.results(app.current_neuron_id).fwhm = new_fwhm(sort_order);
                    if isfield(app.neuron_data.(neuron_name_str), 'fwhm')
                        app.neuron_data.(neuron_name_str).fwhm = app.results(app.current_neuron_id).fwhm;
                    end
                end
                if isfield(app.results(app.current_neuron_id), 'peak_prominences')
                    peak_prominences = app.results(app.current_neuron_id).peak_prominences;
                    new_peak_prominence = [peak_prominences, NaN];
                    app.results(app.current_neuron_id).peak_prominences = new_peak_prominence(sort_order);
                    if isfield(app.neuron_data.(neuron_name_str), 'peak_prominences')
                        app.neuron_data.(neuron_name_str).peak_prominences = app.results(app.current_neuron_id).peak_prominences;
                    end
                end
                if isfield(app.results(app.current_neuron_id), 'peak_widths')
                    peak_widths = app.results(app.current_neuron_id).peak_widths;
                    new_peak_width = [peak_widths, NaN];
                    app.results(app.current_neuron_id).peak_widths = new_peak_width(sort_order);
                    if isfield(app.neuron_data.(neuron_name_str), 'peak_widths')
                        app.neuron_data.(neuron_name_str).peak_widths = app.results(app.current_neuron_id).peak_widths;
                    end
                end

                RecalculateNeuronStats(app, app.current_neuron_id);
                UpdatePlot(app);
            else
                uialert(app.UIFigure, 'Peak already exists at this index.', 'Add Peak', 'Icon', 'warning', 'Modal', false);
            end
        end
        
        % Delete a peak
        function DeletePeak(app, mouse_x, mouse_y)
            if isempty(app.dff_sig) || app.current_neuron_id > size(app.dff_sig,1)
                return;
            end
            peak_times = app.time_vector(app.results(app.current_neuron_id).peak_indices);
            peak_vals = app.results(app.current_neuron_id).peak_values;
            if isempty(peak_times)
                uialert(app.UIFigure, 'No peaks to delete.', 'Delete Peak', 'Icon', 'warning', 'Modal', false);
                return;
            end
            dist_sq = (peak_times - mouse_x).^2 + (peak_vals - mouse_y).^2;
            [~, peak_to_delete_local_idx] = min(dist_sq);
            app.results(app.current_neuron_id).peak_indices(peak_to_delete_local_idx) = [];
            app.results(app.current_neuron_id).peak_values(peak_to_delete_local_idx) = [];
            if isfield(app.results(app.current_neuron_id), 'fwhm') && ~isempty(app.results(app.current_neuron_id).fwhm)
                app.results(app.current_neuron_id).fwhm(peak_to_delete_local_idx) = [];
            end
            if isfield(app.results(app.current_neuron_id), 'peak_prominences') && ~isempty(app.results(app.current_neuron_id).peak_prominences)
                app.results(app.current_neuron_id).peak_prominences(peak_to_delete_local_idx) = [];
            end
            if isfield(app.results(app.current_neuron_id), 'peak_widths') && ~isempty(app.results(app.current_neuron_id).peak_widths)
                app.results(app.current_neuron_id).peak_widths(peak_to_delete_local_idx) = [];
            end
            neuron_name_str = sprintf('neuron_%d', app.current_neuron_id);
            app.neuron_data.(neuron_name_str).peak_indices = app.results(app.current_neuron_id).peak_indices;
            app.neuron_data.(neuron_name_str).peak_values = app.results(app.current_neuron_id).peak_values;
            if isfield(app.neuron_data.(neuron_name_str), 'fwhm')
                app.neuron_data.(neuron_name_str).fwhm = app.results(app.current_neuron_id).fwhm;
            end
            RecalculateNeuronStats(app, app.current_neuron_id);
            UpdatePlot(app);
        end
        
        % Recalculate neuron statistics
        function RecalculateNeuronStats(app, neuron_id)
            num_frames = size(app.dff_sig, 2);
            peak_indices = app.results(neuron_id).peak_indices;
            app.results(neuron_id).num_spikes = length(peak_indices);
            recording_duration_minutes = num_frames / app.framerate / 60;
            if recording_duration_minutes > 0
                app.results(neuron_id).calcium_event_frequency = app.results(neuron_id).num_spikes / recording_duration_minutes;
            else
                app.results(neuron_id).calcium_event_frequency = 0;
            end
            if length(peak_indices) > 1
                app.results(neuron_id).inter_event_intervals = diff(sort(peak_indices)) / app.framerate;
            else
                app.results(neuron_id).inter_event_intervals = [];
            end
        end
    end
    
    % Callbacks that handle component events
    methods (Access = private)
        % Startup function
        function startupFcn(app)
            assignin('base', 'app', app);
            app.RunAnalysisButton.Enable = 'off';
            app.NeuronDropDown.Enable = 'off';
            app.PreviousNeuronButton.Enable = 'off';
            app.NextNeuronButton.Enable = 'off';
            app.AddPeakButtonClickPlotButton.Enable = 'off';
            app.DeletePeakClickPeakButton.Enable = 'off';
            app.SaveResultsButton.Enable = 'off';
            app.NeuronDropDown.Items = {'N/A'};
            app.NeuronDropDown.Value = 'N/A';
            title(app.UIAxes, 'Load Data to Begin');
            app.crosshairHandles = struct();
            app.MinPeakHeightEditField.Value = app.min_peak_height;
            app.MinPeakProminenceEditField.Value = app.min_peak_prominence;
            app.MinPeakDistanceEditField.Value = app.min_peak_distance_sec;
            setupScrollWheelZoom(app);
        end
        
        % Load data button pushed
        function LoadDataButtonPushed(app, event)
            resetInteractionModes(app);
            [fileName, filePath] = uigetfile({'*.mat';'*.xlsx;*.xls'}, 'Select Data File');
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'No file selected.', 'File Load');
                return;
            end
            figure(app.UIFigure);
            fullPath = fullfile(filePath, fileName);
            [~, ~, ext] = fileparts(fileName);
            app.framerate = app.FramerateEditField.Value;
            try
                if strcmpi(ext, '.mat')
                    dataLoaded = load(fullPath);
                    varNames = fieldnames(dataLoaded);
                    if isempty(varNames)
                        uialert(app.UIFigure, 'MAT file is empty.', 'Load Error'); return;
                    end
                    if length(varNames) == 1
                        app.dff_sig = dataLoaded.(varNames{1});
                    else
                        [indx, tf] = listdlg('PromptString', {'Select dF/F variable: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', varNames, ...
                            'Name', 'Select Variable', 'OKString', 'Select');
                        if tf
                            app.dff_sig = dataLoaded.(varNames{indx});
                        else
                            uialert(app.UIFigure, 'No variable selected.', 'Load Error'); return;
                        end
                    end
                elseif any(strcmpi(ext, {'.xlsx', '.xls'}))
                    sheetNames = sheetnames(fullPath);
                    if isempty(sheetNames)
                        uialert(app.UIFigure, 'Excel file has no sheets.', 'Load Error'); return;
                    end
                    if length(sheetNames) == 1
                        app.dff_sig = readmatrix(fullPath, 'Sheet', sheetNames{1});
                    else
                        [indx, tf] = listdlg('PromptString', {'Select sheet: (rows=neurons, cols=frames)'}, ...
                            'SelectionMode', 'single', 'ListString', sheetNames, ...
                            'Name', 'Select Sheet', 'OKString', 'Select');
                        if tf
                            app.dff_sig = readmatrix(fullPath, 'Sheet', sheetNames{indx});
                        else
                            uialert(app.UIFigure, 'No sheet selected.', 'Load Error'); return;
                        end
                    end
                else
                    uialert(app.UIFigure, 'Unsupported file type.', 'Load Error'); return;
                end
                figure(app.UIFigure);
                if ~ismatrix(app.dff_sig) || isempty(app.dff_sig) || ~isnumeric(app.dff_sig)
                    uialert(app.UIFigure, 'Selected data is not a valid numeric matrix or is empty.', 'Data Error');
                    app.dff_sig = []; return;
                end
                [num_neurons, num_frames] = size(app.dff_sig);
                app.time_vector = (1:num_frames) / app.framerate;
                app.RunAnalysisButton.Enable = 'on';
                app.NeuronDropDown.Enable = 'off';
                app.PreviousNeuronButton.Enable = 'off';
                app.NextNeuronButton.Enable = 'off';
                app.AddPeakButtonClickPlotButton.Enable = 'off';
                app.DeletePeakClickPeakButton.Enable = 'off';
                app.SaveResultsButton.Enable = 'off';
                app.NeuronDropDown.Items = {'N/A'};
                app.NeuronDropDown.Value = 'N/A';
                cla(app.UIAxes);
                title(app.UIAxes, 'Data Loaded. Press "Run Analysis".');
                xlabel(app.UIAxes, 'Time (s)');
                ylabel(app.UIAxes, '\DeltaF/F');
                grid(app.UIAxes, 'on');
                uialert(app.UIFigure, sprintf('Data loaded: %d neurons, %d frames.', num_neurons, num_frames), 'Load Success','Icon','success');
            catch ME
                uialert(app.UIFigure, ['Error loading data: ' ME.message char(10) ME.getReport('basic')], 'Load Error');
                app.dff_sig = [];
                app.RunAnalysisButton.Enable = 'off';
            end
        end
        
        % Run analysis button pushed
        function RunAnalysisButtonPushed(app, event)
            resetInteractionModes(app);
            if isempty(app.dff_sig)
                uialert(app.UIFigure, 'No data loaded to analyze.', 'Analysis Error');
                return;
            end
            app.min_peak_height = app.MinPeakHeightEditField.Value;
            app.min_peak_prominence = app.MinPeakProminenceEditField.Value;
            app.min_peak_distance_sec = app.MinPeakDistanceEditField.Value;
            if app.min_peak_height <= 0
                uialert(app.UIFigure, 'Minimum Peak Height must be positive.', 'Parameter Error');
                return;
            end
            if app.min_peak_prominence <= 0
                uialert(app.UIFigure, 'Minimum Peak Prominence must be positive.', 'Parameter Error');
                return;
            end
            if app.min_peak_distance_sec <= 0
                uialert(app.UIFigure, 'Minimum Peak Distance must be positive.', 'Parameter Error');
                return;
            end
            progDlg = uiprogressdlg(app.UIFigure, 'Title', 'Analyzing Data', 'Message', 'Initializing...', 'Indeterminate', 'off', 'Cancelable', 'on');
            [num_neurons, num_frames] = size(app.dff_sig);
            min_peak_dist_frames = app.min_peak_distance_sec * app.framerate;
            temp_results = repmat(struct(...
                'neuron_id', 0, 'peak_indices', [], 'peak_values', [], ...
                'peak_widths', [], 'peak_prominences', [], 'fwhm', [], ...
                'num_spikes', 0, 'calcium_event_frequency', 0, ...
                'inter_event_intervals', []), num_neurons, 1);
            temp_neuron_data = struct();
            cleanupObj = onCleanup(@() delete(progDlg));
            for n = 1:num_neurons
                if progDlg.CancelRequested
                    uialert(app.UIFigure, 'Analysis cancelled by user.', 'Analysis Cancelled');
                    return;
                end
                progDlg.Message = sprintf('Processing Neuron %d/%d', n, num_neurons);
                progDlg.Value = n / num_neurons;
                trace = app.dff_sig(n, :);
                baseline = prctile(trace, 30);
                [peak_values, peak_indices, peak_widths_frames, peak_prominences] = findpeaks(trace, ...
                    'MinPeakHeight', app.min_peak_height, ...
                    'MinPeakProminence', app.min_peak_prominence, ...
                    'MinPeakDistance', min_peak_dist_frames);
                temp_results(n).neuron_id = n;
                temp_results(n).peak_indices = peak_indices;
                temp_results(n).peak_values = peak_values;
                temp_results(n).peak_widths = peak_widths_frames;
                temp_results(n).peak_prominences = peak_prominences;
                fwhm_seconds_all = NaN(1, length(peak_indices));
                for p = 1:length(peak_indices)
                    peak_idx = peak_indices(p);
                    peak_val = peak_values(p);
                    half_max = (peak_val - baseline) / 2 + baseline;
                    left_idx = peak_idx;
                    while left_idx > 1 && trace(left_idx) > half_max
                        left_idx = left_idx - 1;
                    end
                    right_idx = peak_idx;
                    while right_idx < num_frames && trace(right_idx) > half_max
                        right_idx = right_idx + 1;
                    end
                    if left_idx > 1 && trace(left_idx) <= half_max && trace(left_idx-1) > half_max && ...
                            right_idx < num_frames && trace(right_idx) <= half_max && trace(right_idx+1) > half_max
                        y1 = trace(left_idx-1); y2 = trace(left_idx);
                        x1_frame = left_idx-1; x2_frame = left_idx;
                        left_cross_frame = x1_frame + (half_max - y1) * (x2_frame - x1_frame) / (y2 - y1);
                        y1 = trace(right_idx); y2 = trace(right_idx+1);
                        x1_frame = right_idx; x2_frame = right_idx+1;
                        right_cross_frame = x1_frame + (half_max - y1) * (x2_frame - x1_frame) / (y2 - y1);
                        fwhm_frames = right_cross_frame - left_cross_frame;
                        fwhm_seconds_all(p) = fwhm_frames / app.framerate;
                    end
                end
                temp_results(n).fwhm = fwhm_seconds_all;
                recording_duration_minutes = num_frames / app.framerate / 60;
                temp_results(n).num_spikes = length(peak_indices);
                if recording_duration_minutes > 0
                    temp_results(n).calcium_event_frequency = temp_results(n).num_spikes / recording_duration_minutes;
                else
                    temp_results(n).calcium_event_frequency = 0;
                end
                if length(peak_indices) > 1
                    temp_results(n).inter_event_intervals = diff(sort(peak_indices)) / app.framerate;
                else
                    temp_results(n).inter_event_intervals = [];
                end
                neuron_name = sprintf('neuron_%d', n);
                temp_neuron_data.(neuron_name).trace = trace;
                temp_neuron_data.(neuron_name).time = app.time_vector;
                temp_neuron_data.(neuron_name).peak_indices = peak_indices;
                temp_neuron_data.(neuron_name).peak_values = peak_values;
                temp_neuron_data.(neuron_name).fwhm = fwhm_seconds_all;
                if isfield(temp_results(n), 'peak_prominences')
                    temp_neuron_data.(neuron_name).peak_prominences = temp_results(n).peak_prominences;
                end
            end
            app.results = temp_results;
            app.neuron_data = temp_neuron_data;
            neuronItems = arrayfun(@(x) sprintf('Neuron %d', x), 1:num_neurons, 'UniformOutput', false);
            if isempty(neuronItems)
                neuronItems = {'N/A'};
            end
            app.NeuronDropDown.Items = neuronItems;
            app.NeuronDropDown.Value = neuronItems{1};
            app.current_neuron_id = 1;
            app.NeuronDropDown.Enable = 'on';
            app.PreviousNeuronButton.Enable = 'on';
            app.NextNeuronButton.Enable = 'on';
            app.AddPeakButtonClickPlotButton.Enable = 'on';
            app.DeletePeakClickPeakButton.Enable = 'on';
            app.SaveResultsButton.Enable = 'on';
            delete(progDlg);
            UpdatePlot(app);
            uialert(app.UIFigure, 'Analysis complete.', 'Analysis Success');
        end
        
        % Neuron dropdown value changed
        function NeuronDropDownValueChanged(app, event)
            resetInteractionModes(app);
            if strcmp(app.NeuronDropDown.Value, 'N/A') || isempty(app.results) || isempty(app.dff_sig)
                app.current_neuron_id = 0;
                UpdatePlot(app);
                return;
            end
            selectedNeuronStr = app.NeuronDropDown.Value;
            app.current_neuron_id = str2double(regexp(selectedNeuronStr, '\d+', 'match', 'once'));
            UpdatePlot(app);
        end
        
        % Previous neuron button pushed
        function PreviousNeuronButtonPushed(app, event)
            resetInteractionModes(app);
            if isempty(app.results) || app.current_neuron_id <= 1
                return;
            end
            app.current_neuron_id = app.current_neuron_id - 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            UpdatePlot(app);
        end
        
        % Next neuron button pushed
        function NextNeuronButtonPushed(app, event)
            resetInteractionModes(app);
            if isempty(app.results) || app.current_neuron_id >= length(app.results)
                return;
            end
            app.current_neuron_id = app.current_neuron_id + 1;
            app.NeuronDropDown.Value = sprintf('Neuron %d', app.current_neuron_id);
            UpdatePlot(app);
        end
        
        % Add peak button pushed
        function AddPeakButtonClickPlotButtonPushed(app, event)
            if app.isAddPeakMode
                resetInteractionModes(app);
            else
                resetInteractionModes(app);
                app.isAddPeakMode = true;
                app.AddPeakButtonClickPlotButton.BackgroundColor = [0.7 1.0 0.7];
                uialert(app.UIFigure, 'Add Peak Mode: Move mouse to position and press Enter to add a peak.', 'Mode Changed', 'Icon','info', 'Modal', false);
            end
            UpdatePlot(app);
        end
        
        % Delete peak button pushed
        function DeletePeakClickPeakButtonPushed(app, event)
            if app.isDeletePeakMode
                resetInteractionModes(app);
            else
                resetInteractionModes(app);
                app.isDeletePeakMode = true;
                app.DeletePeakClickPeakButton.BackgroundColor = [1.0 0.7 0.7];
                uialert(app.UIFigure, 'Delete Peak Mode: Move mouse near a peak and press Enter to delete it.', 'Mode Changed', 'Icon','info', 'Modal', false);
            end
            UpdatePlot(app);
        end
        
        % Save results button pushed
        function SaveResultsButtonPushed(app, event)
            resetInteractionModes(app);
            if isempty(app.results)
                uialert(app.UIFigure, 'No results to save.', 'Save Error');
                return;
            end
            [fileName, filePath] = uiputfile({'*.mat', 'MAT-file (*.mat)'}, 'Save Analysis Results');
            if isequal(fileName, 0) || isequal(filePath, 0)
                uialert(app.UIFigure, 'Save cancelled.', 'Save Operation');
                return;
            end
            fullPathMat = fullfile(filePath, fileName);
            results = app.results;
            neuron_data = app.neuron_data;
            time_vector = app.time_vector;
            framerate = app.framerate;
            analysis_date = datestr(now);
            try
                save(fullPathMat, 'results', 'neuron_data', 'time_vector', 'framerate', 'analysis_date', '-v7.3');
                num_neurons = length(results);
                mean_fwhm = zeros(1, num_neurons);
                for n_idx = 1:num_neurons
                    if ~isempty(results(n_idx).fwhm) && ~all(isnan(results(n_idx).fwhm))
                        mean_fwhm(n_idx) = mean(results(n_idx).fwhm, 'omitnan');
                    else
                        mean_fwhm(n_idx) = NaN;
                    end
                end
                stats_table = table((1:num_neurons)', ...
                    [results.num_spikes]', ...
                    [results.calcium_event_frequency]', ...
                    mean_fwhm', ...
                    'VariableNames', {'NeuronID', 'NumEvents', 'EventFreq_perMin', 'MeanFWHM_s'});
                [~, nameNoExt, ~] = fileparts(fullPathMat);
                fullPathCsv = fullfile(filePath, [nameNoExt '_summary_stats.csv']);
                writetable(stats_table, fullPathCsv);
                uialert(app.UIFigure, sprintf('Results saved to:\n%s\n%s', fullPathMat, fullPathCsv), 'Save Success','Icon','success');
            catch ME
                uialert(app.UIFigure, ['Error saving results: ' ME.message], 'Save Error');
            end
        end
    end
    
    % Component initialization
    methods (Access = private)
        % Create UI components
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1200 700];
            app.UIFigure.Name = 'Calcium Imaging Analysis Tool';
            
            % File Operations Panel
            app.FileOperationsPanel = uipanel(app.UIFigure);
            app.FileOperationsPanel.Title = 'File Operations';
            app.FileOperationsPanel.Position = [20 580 300 100];
            app.FramerateHzLabel = uilabel(app.FileOperationsPanel);
            app.FramerateHzLabel.HorizontalAlignment = 'right';
            app.FramerateHzLabel.Position = [10 40 90 22];
            app.FramerateHzLabel.Text = 'Framerate (Hz):';
            app.FramerateEditField = uieditfield(app.FileOperationsPanel, 'numeric');
            app.FramerateEditField.ValueDisplayFormat = '%.2f';
            app.FramerateEditField.Position = [110 40 100 22];
            app.FramerateEditField.Value = app.framerate;
            app.LoadDataButton = uibutton(app.FileOperationsPanel, 'push');
            app.LoadDataButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataButtonPushed, true);
            app.LoadDataButton.Position = [10 10 100 22];
            app.LoadDataButton.Text = 'Load Data';
            app.RunAnalysisButton = uibutton(app.FileOperationsPanel, 'push');
            app.RunAnalysisButton.ButtonPushedFcn = createCallbackFcn(app, @RunAnalysisButtonPushed, true);
            app.RunAnalysisButton.Position = [120 10 100 22];
            app.RunAnalysisButton.Text = 'Run Analysis';
            
            % Peak Detection Parameters Panel
            app.PeakDetectionParametersPanel = uipanel(app.UIFigure);
            app.PeakDetectionParametersPanel.Title = 'Peak Detection Parameters';
            app.PeakDetectionParametersPanel.Position = [20 430 300 140];
            app.MinPeakHeightLabel = uilabel(app.PeakDetectionParametersPanel);
            app.MinPeakHeightLabel.HorizontalAlignment = 'right';
            app.MinPeakHeightLabel.Position = [10 90 100 22];
            app.MinPeakHeightLabel.Text = 'Min Peak Height:';
            app.MinPeakHeightEditField = uieditfield(app.PeakDetectionParametersPanel, 'numeric');
            app.MinPeakHeightEditField.ValueDisplayFormat = '%.2f';
            app.MinPeakHeightEditField.Position = [120 90 100 22];
            app.MinPeakHeightEditField.Value = app.min_peak_height;
            app.MinPeakProminenceLabel = uilabel(app.PeakDetectionParametersPanel);
            app.MinPeakProminenceLabel.HorizontalAlignment = 'right';
            app.MinPeakProminenceLabel.Position = [10 60 100 22];
            app.MinPeakProminenceLabel.Text = 'Min Prominence:';
            app.MinPeakProminenceEditField = uieditfield(app.PeakDetectionParametersPanel, 'numeric');
            app.MinPeakProminenceEditField.ValueDisplayFormat = '%.2f';
            app.MinPeakProminenceEditField.Position = [120 60 100 22];
            app.MinPeakProminenceEditField.Value = app.min_peak_prominence;
            app.MinPeakDistanceLabel = uilabel(app.PeakDetectionParametersPanel);
            app.MinPeakDistanceLabel.HorizontalAlignment = 'right';
            app.MinPeakDistanceLabel.Position = [10 30 100 22];
            app.MinPeakDistanceLabel.Text = 'Min Distance (s):';
            app.MinPeakDistanceEditField = uieditfield(app.PeakDetectionParametersPanel, 'numeric');
            app.MinPeakDistanceEditField.ValueDisplayFormat = '%.2f';
            app.MinPeakDistanceEditField.Position = [120 30 100 22];
            app.MinPeakDistanceEditField.Value = app.min_peak_distance_sec;
            
            % Neuron Display & Filtering Panel
            app.NeuronDisplayFilteringPanel = uipanel(app.UIFigure);
            app.NeuronDisplayFilteringPanel.Title = 'Neuron Display & Filtering';
            app.NeuronDisplayFilteringPanel.Position = [20 50 300 370];
            app.SelectNeuronLabel = uilabel(app.NeuronDisplayFilteringPanel);
            app.SelectNeuronLabel.HorizontalAlignment = 'right';
            app.SelectNeuronLabel.Position = [10 320 85 22];
            app.SelectNeuronLabel.Text = 'Select Neuron:';
            app.NeuronDropDown = uidropdown(app.NeuronDisplayFilteringPanel);
            app.NeuronDropDown.ValueChangedFcn = createCallbackFcn(app, @NeuronDropDownValueChanged, true);
            app.NeuronDropDown.Position = [105 320 170 22];
            app.PreviousNeuronButton = uibutton(app.NeuronDisplayFilteringPanel, 'push');
            app.PreviousNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @PreviousNeuronButtonPushed, true);
            app.PreviousNeuronButton.Position = [10 290 85 22];
            app.PreviousNeuronButton.Text = 'Previous';
            app.NextNeuronButton = uibutton(app.NeuronDisplayFilteringPanel, 'push');
            app.NextNeuronButton.ButtonPushedFcn = createCallbackFcn(app, @NextNeuronButtonPushed, true);
            app.NextNeuronButton.Position = [105 290 85 22];
            app.NextNeuronButton.Text = 'Next';
            app.AddPeakButtonClickPlotButton = uibutton(app.NeuronDisplayFilteringPanel, 'push');
            app.AddPeakButtonClickPlotButton.ButtonPushedFcn = createCallbackFcn(app, @AddPeakButtonClickPlotButtonPushed, true);
            app.AddPeakButtonClickPlotButton.Position = [10 260 170 22];
            app.AddPeakButtonClickPlotButton.Text = 'Add Peak (Press Enter)';
            app.DeletePeakClickPeakButton = uibutton(app.NeuronDisplayFilteringPanel, 'push');
            app.DeletePeakClickPeakButton.ButtonPushedFcn = createCallbackFcn(app, @DeletePeakClickPeakButtonPushed, true);
            app.DeletePeakClickPeakButton.Position = [10 230 170 22];
            app.DeletePeakClickPeakButton.Text = 'Delete Peak (Press Enter)';
            app.SaveResultsButton = uibutton(app.NeuronDisplayFilteringPanel, 'push');
            app.SaveResultsButton.ButtonPushedFcn = createCallbackFcn(app, @SaveResultsButtonPushed, true);
            app.SaveResultsButton.Position = [10 200 100 22];
            app.SaveResultsButton.Text = 'Save Results';
            
            % UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Neural Signal and Peaks')
            xlabel(app.UIAxes, 'Time (s)')
            ylabel(app.UIAxes, '\DeltaF/F')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [350 50 800 600];
            grid(app.UIAxes, 'on');
            app.UIAxes.HitTest = 'on';
            
            app.UIFigure.Visible = 'on';
        end
    end
    
    % App creation and deletion
    methods (Access = public)
        function app = CalciumPeakFinderAPP
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            delete(app.UIFigure)
        end
    end
end