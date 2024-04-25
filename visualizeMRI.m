function visualizeMRI()

    % Select directory containing H5 files
    directory = uigetdir('Select directory containing H5 files');
    if directory == 0
        disp('No directory selected. Exiting...');
        return;
    end
    
    % Load H5 files
    files = dir(fullfile(directory, '*.h5'));
    num_files = numel(files);
    if num_files == 0
        disp('No H5 files found in selected directory. Exiting...');
        return;
    end
    
    % Initialize variables
    current_file_index = 1;
    current_slice = 1;
    display_tumor_mask = false;
    
    % Create figure
    fig = figure('Name', 'MRI Visualization Tool', 'Position', [100, 100, 800, 600]);
    
    % UI elements
    file_dropdown = uicontrol('Style', 'popupmenu', 'String', {files.name}, ...
        'Position', [20, 550, 200, 30], 'Callback', @fileDropdownCallback);
    
    channel_dropdown = uicontrol('Style', 'popupmenu', 'String', {'Channel 1', 'Channel 2', 'Channel 3'}, ...
        'Position', [250, 550, 150, 30], 'Callback', @channelDropdownCallback);
    
    tumor_checkbox = uicontrol('Style', 'checkbox', 'String', 'Show Tumor Mask', ...
        'Position', [420, 550, 150, 30], 'Callback', @tumorCheckboxCallback);
    
    slice_slider = uicontrol('Style', 'slider', 'Min', 1, 'Max', 100, 'Value', 1, ...
        'SliderStep', [1/(num_files-1), 10/(num_files-1)], 'Position', [600, 550, 150, 30], ...
        'Callback', @sliceSliderCallback);
    
    slice_text = uicontrol('Style', 'text', 'String', 'Slice:', ...
        'Position', [560, 550, 40, 30]);
    
    % Display initial MRI slice
    displaySlice();
    
    % Callback functions
    function fileDropdownCallback(src, ~)
        current_file_index = src.Value;
        displaySlice();
    end

    function channelDropdownCallback(src, ~)
        displaySlice();
    end

    function tumorCheckboxCallback(src, ~)
        display_tumor_mask = src.Value;
        displaySlice();
    end

    function sliceSliderCallback(src, ~)
        current_slice = round(src.Value);
        displaySlice();
    end

    function displaySlice()
        % Load MRI data and tumor mask
        file_path = fullfile(directory, files(current_file_index).name);
        mri_data = h5read(file_path, '/mri_data');
        tumor_mask = h5read(file_path, '/tumor_mask');
        
        % Get selected channel
        channel_index = channel_dropdown.Value;
        
        % Display MRI slice
        imshow(mri_data(:,:,current_slice,channel_index), []);
        title(sprintf('MRI Slice %d (Channel %d)', current_slice, channel_index));
        
        % Overlay tumor mask if selected
        if display_tumor_mask
            hold on;
            contour(tumor_mask(:,:,current_slice), 'r');
            hold off;
        end
    end

end