function visualizeMRI
    % Create the main figure window
    fig = uifigure('Name', 'MRI Analyzer', 'Position', [100 100 800 500]);

    % Create UI components
    loadDirButton = uibutton(fig, 'Text', 'Load Slice Directory', 'Position', [50 450 150 30], 'ButtonPushedFcn', @loadSliceDirectory);
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
    maxTumorAreaLabel = uilabel(fig, 'Text', '', 'Position', [700 400 100 30]);
    maxTumorDiameterLabel = uilabel(fig, 'Text', '', 'Position', [700 350 100 30]);
    outerLayerInvolvementLabel = uilabel(fig, 'Text', '', 'Position', [700 300 100 30]);

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
        % Implement functionality to extract conventional features
        disp('Extracting conventional features...');
        
        % Calculate maximum tumor area, maximum tumor diameter, and outer layer involvement
        % [maxTumorArea, maxTumorDiameter, outerLayerInvolvement] = calculateConventionalFeatures();
        maxTumorArea = 1000;
        maxTumorDiameter = 50;
        outerLayerInvolvement = 10; % Dummy values for demonstration 
        
        % Display calculated features
        maxTumorAreaLabel.Text = ['Max Tumor Area: ' num2str(maxTumorArea)];
        maxTumorDiameterLabel.Text = ['Max Tumor Diameter: ' num2str(maxTumorDiameter)];
        outerLayerInvolvementLabel.Text = ['Outer Layer Involvement: ' num2str(outerLayerInvolvement) '%'];
    end

    function extractRadiomicFeatures(~, ~)
        % Implement functionality to extract radiomic features
        disp('Radiomic features extracted');
    end

    function updateImages()
        % Implement functionality to update displayed images
        if isempty(currentDirectory)
            disp('No directory selected.');
            return;
        end
    
        % Construct the filename based on current volume and slice
        filename = fullfile(currentDirectory, sprintf('volume_%d_slice_%d.h5', currentVolume, currentSlice));
    
        % Check if the file exists
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
            for i = 1:numel(colors)
                try
                    mask = squeeze(maskData(i, :, :));
                    contour(ax, mask, colors{i}, 'LineWidth', 1);
                catch
                    disp(['Error reading mask data for mask ' num2str(i)]);
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

    function [maxTumorArea, maxTumorDiameter, outerLayerInvolvement] = calculateConventionalFeatures()
        % Calculate Maximum Tumor Area
        maxTumorArea = 0;
        for slice = 1:154 % Assuming 154 slices
            mask = h5read(filename, '/mask', [1 1 slice], [512 512 1]); % Assuming mask dimensions are 512x512
            tumorArea = sum(mask(:)); % Count tumorous pixels
            maxTumorArea = max(maxTumorArea, tumorArea);
        end
        
        % Calculate Maximum Tumor Diameter
        maxTumorDiameter = 0;
        for slice = 1:154 % Assuming 154 slices
            mask = h5read(filename, '/mask', [1 1 slice], [512 512 1]); % Assuming mask dimensions are 512x512
            props = regionprops(mask, 'MajorAxisLength'); % Get major axis length of tumor components
            if ~isempty(props)
                maxTumorDiameter = max(maxTumorDiameter, max([props.MajorAxisLength]));
            end
        end
        
        % Calculate Outer Layer Involvement
        outerLayerThickness = 5; % Constant thickness of outer layer
        outerLayerPixels = outerLayerThickness * 512 * 154; % Assuming mask dimensions are 512x512 and 154 slices
        tumorPixels = sum(h5read(filename, '/mask'), 'all'); % Total tumor pixels
        outerLayerInvolvement = (tumorPixels / outerLayerPixels) * 100;
    end
end
