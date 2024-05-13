function visualizeMRI
    % Create the main figure window
    fig = uifigure('Name', 'MRI Analyzer', 'Position', [100 100 800 500]);

    % Create UI components
    loadDirButton = uibutton(fig, 'Text', 'Load Slice Directory', 'Position', [50 450 150 30], 'ButtonPushedFcn', @loadSliceDirectory); %#ok<*NASGU>
    channelDropdownLabel = uilabel(fig, 'Text', 'Channel:', 'Position', [250 480 60 15]);
    channelDropdown = uidropdown(fig, 'Items', {'T1', 'T1Gd', 'T2', 'T2-FLAIR'}, 'Position', [250 450 100 30], 'ValueChangedFcn', @changeChannel);
    annotationDropdownLabel = uilabel(fig, 'Text', 'Annotation:', 'Position', [400 480 80 15]);
    annotationDropdown = uidropdown(fig, 'Items', {'On', 'Off'}, 'Position', [400 450 100 30], 'ValueChangedFcn', @toggleAnnotation);
    sliceSliderLabel = uilabel(fig, 'Text', 'Slice:', 'Position', [50 415 50 15]);
    sliceSlider = uislider(fig, 'Limits', [0 154], 'Position', [110 410 640 3], 'Value', 1, 'ValueChangedFcn', @updateSlice);
    conventionalButton = uibutton(fig, 'Text', 'Extract Conventional Features', 'Position', [50 350 200 30], 'ButtonPushedFcn', @extractConventionalFeatures);
    radiomicButton = uibutton(fig, 'Text', 'Extract Radiomic Features', 'Position', [300 350 200 30], 'ButtonPushedFcn', @extractRadiomicFeatures);

    % Add a UIAxes component for displaying the image
    ax = uiaxes(fig, 'Position', [100 100 600 250]);

    % Add UI labels for displaying calculated features
    maxTumorAreaLabel = uilabel(fig, 'Text', '', 'Position', [50 50 200 15]);
    maxTumorDiameterLabel = uilabel(fig, 'Text', '', 'Position', [50 30 200 15]);
    outerLayerInvolvementLabel = uilabel(fig, 'Text', '', 'Position', [50 10 200 15]);

    % Define variables
    currentDirectory = '';
    currentChannel = 'T1';
    currentSlice = 1;
    currentVolume = 1;  % Initialize currentVolume

    % Callback functions
    function loadSliceDirectory(~, ~)
        % Implement functionality to load directory
        directory = uigetdir();
        if directory == 0
            % User cancelled
            return;
        end
        
        % Process the directory
        disp(['Selected directory: ' directory]);
        currentDirectory = directory;
        
        % Extract volume number from the directory name
        [~, currentVolumeStr, ~] = fileparts(directory);
        currentVolume = str2double(strrep(currentVolumeStr, 'volume_', ''));
        
        updateImages(); % Update images after directory is loaded
    end

    function changeChannel(~, ~)
        % Implement functionality to change displayed channel
        currentChannel = channelDropdown.Value;
        disp(['Channel changed to: ' currentChannel]);
        updateImages();
    end

    function toggleAnnotation(~, ~)
        % Implement functionality to toggle tumor annotation
        disp('Annotation toggled');
        updateImages();
    end

    function extractConventionalFeatures(~, ~)
        disp('Extracting conventional features...');        
        [maxTumorArea, maxTumorDiameter, outerLayerInvolvement, sliceID] = calculateConventionalFeatures();
        
        maxTumorAreaLabel.Text = ['Max Tumor Area: ' num2str(maxTumorArea) ', (ID: ' num2str(sliceID) ')'];
        maxTumorDiameterLabel.Text = ['Max Tumor Diameter: ' num2str(maxTumorDiameter)];
        outerLayerInvolvementLabel.Text = ['Outer Layer Involvement: ' num2str(outerLayerInvolvement) '%'];
    end

    function extractRadiomicFeatures(~, ~)
        disp('Radiomic features extracted');
        filename = fullfile(currentDirectory, sprintf('volume_%d_slice_%d.h5', currentVolume, currentSlice));
        if ~exist(filename, 'file')
            disp(['File not found: ' filename]);
            return;
        end
        imageData = h5read(filename, '/image');
        maskData = h5read(filename, '/mask');
        
        image = squeeze(imageData(1, :, :));
        mask = squeeze(maskData(1, :, :));

        % Extract radiomic features
        features = radiomics_features(image, mask);

        % Save the features to a CSV file
        output_csv = 'radiomic_features.csv';
        writetable(features, output_csv);
    end

    function updateImages()
        if isempty(currentDirectory)
            disp('No directory selected.');
            return;
        end

        filename = fullfile(currentDirectory, sprintf('volume_%d_slice_%d.h5', currentVolume, currentSlice));
        if ~exist(filename, 'file')
            disp(['File not found: ' filename]);
            return;
        end
    
        try
            % Read the image data from the HDF5 file
            imageData = h5read(filename, '/image');
            maskData = h5read(filename, '/mask'); % Load mask data
    
            % Display the size and class of the loaded image data
            disp(['Loaded image data size: ' num2str(size(imageData))]);
            disp(['Image data class: ' class(imageData)]);
    
            % Display the selected channel in the UIAxes
            channelIndex = getChannelIndex(currentChannel);
            imagesc(ax, squeeze(imageData(channelIndex, :, :)));
            colormap(ax, gray);
            axis(ax, 'image');
            hold(ax, 'on'); 
    
            colors = {'r', 'g', 'b'};
    
            % Overlay masks on the image
            if strcmp(annotationDropdown.Value, 'On')
                for i = 1:numel(colors)
                    try
                        mask = squeeze(maskData(i, :, :));
                        contour(ax, mask, colors{i}, 'LineWidth', 1);
                    catch
                        disp(['Error reading mask data for mask ' num2str(i)]);
                    end
                end
            end


            hold(ax, 'off'); % Release the hold on the current axes
            channelIndex = channelIndex - 1;
            if channelIndex == 0
                channelIndex = 4;
            end
            title(ax, ['Channel ' num2str(channelIndex)]);
        catch ME
            disp(['Error reading HDF5 file: ' ME.message]);
            return;
        end
    end

    function index = getChannelIndex(channel)
        % Define channel indices
        channelIndices = containers.Map({'T2-FLAIR', 'T1', 'T1Gd', 'T2'}, {1, 2, 3, 4});
        index = channelIndices(channel);
    end

    % Callback function to update slice value
    function updateSlice(src, ~)
        currentSlice = round(src.Value);
        disp(['Slice changed to: ' num2str(currentSlice)]);
        updateImages();
    end

    function [maxTumorArea, maxTumorDiameter, outerLayerInvolvement, sliceID] = calculateConventionalFeatures()
    % Initialize variables to store results for all volumes
    results = [];
    outerLayerThickness = 5;

    for i = 1:154
        try
            filename = fullfile(currentDirectory, sprintf('volume_%d_slice_%d.h5', currentVolume, i));
            if ~exist(filename, 'file')
                disp(['File not found: ' filename]);
                throw(MException('MATLAB:FileNotFound', 'File not found'));
            end

            maskData = h5read(filename, '/mask');
            count = 0;
            maxDistance = 0;

            % gets Max area of tumor with slice ID
            for j = 1:3
                mask = squeeze(maskData(j, :, :));
                [rows, cols] = find(mask);  % Get x/y coordinates of tumor pixels
                numPixels = numel(rows);

                % Calculate maximum tumor diameter by finding the furthest apart pixels
                for k = 1:numPixels
                    for l = (k + 1):numPixels
                        distance = sqrt((rows(k) - rows(l))^2 + (cols(k) - cols(l))^2);
                        if distance > maxDistance
                            maxDistance = distance;
                        end
                    end
                end
                
                count = count + numPixels;  
            end

            % Calculate outer layer involvement
            % Assuming outer layer thickness is constant
            outerLayerThickness = 5;
            outerLayerPixels = outerLayerThickness * numel(mask);
            outerLayerInvolvement = (count / outerLayerPixels) * 100;

            % Calculate outer layer involvement

            % Store results for this volume
            results = [results; currentVolume, i, count, maxDistance, outerLayerInvolvement];

        catch ME
            disp(['Error reading mask data: ' ME.message]);
            maxTumorArea = -1;
            maxTumorDiameter = -1;
            outerLayerInvolvement = -1;
            sliceID = -1;
            return;
        end
    end

    % Save results to CSV file with column titles
    csvFilename = 'conventional_features.csv';
    columnTitles = ["Volume", "Slice", "TumorArea", "TumorDiameter", "OuterLayerInvolvement"];
    writematrix(columnTitles, csvFilename, 'Delimiter', ',');  % Write column titles
    dlmwrite(csvFilename, results, '-append', 'Delimiter', ',');  % Append results
    disp(['Conventional features saved to ' csvFilename]);

    % Find maximum values
    maxTumorArea = max(results(:, 3));
    maxTumorDiameter = max(results(:, 4));
    outerLayerInvolvement = max(results(:, 5));
    sliceID = find(results(:, 3) == maxTumorArea, 1);
end

end