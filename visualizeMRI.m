function visualizeMRI
    % Create the main figure window
    fig = uifigure('Name', 'MRI Analyzer', 'Position', [100 100 800 500]);

    % Create UI components
    loadDirButton = uibutton(fig, 'Text', 'Load Slice Directory', 'Position', [50 450 150 30], 'ButtonPushedFcn', @loadSliceDirectory);
    channelDropdown = uidropdown(fig, 'Items', {'T1', 'T1Gd', 'T2', 'T2-FLAIR'}, 'Position', [250 450 100 30], 'ValueChangedFcn', @changeChannel);
    annotationDropdown = uidropdown(fig, 'Items', {'On', 'Off'}, 'Position', [400 450 100 30], 'ValueChangedFcn', @toggleAnnotation);
    sliceSlider = uislider(fig, 'Limits', [1 154], 'Position', [50 400 700 3], 'ValueChangedFcn', @changeSlice);
    conventionalButton = uibutton(fig, 'Text', 'Extract Conventional Features', 'Position', [50 350 200 30], 'ButtonPushedFcn', @extractConventionalFeatures);
    radiomicButton = uibutton(fig, 'Text', 'Extract Radiomic Features', 'Position', [300 350 200 30], 'ButtonPushedFcn', @extractRadiomicFeatures);
    
    % Add a UIAxes component for displaying the image
    ax = uiaxes(fig, 'Position', [100 100 600 250]);
    
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

    function changeSlice(~, ~)
        % Implement functionality to change displayed slice
        currentSlice = round(sliceSlider.Value);
        disp(['Slice changed to: ' num2str(currentSlice)]);
        updateImages();
    end

    function extractConventionalFeatures(~, ~)
        % Implement functionality to extract conventional features
        disp('Conventional features extracted');
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

        % Display the size and class of the loaded image data
        disp(['Loaded image data size: ' num2str(size(imageData))]);
        disp(['Image data class: ' class(imageData)]);

        % Display the selected channel in the UIAxes
        channelIndex = getChannelIndex(currentChannel);
        imshow(squeeze(imageData(channelIndex, :, :)), 'Parent', ax);
        colormap(ax, gray);
        axis(ax, 'image');
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

end
