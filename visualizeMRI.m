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
    current_slice = 1;
    display_tumor_mask = false;
    
    % Create figure
    fig = figure('Name', 'MRI Visualization Tool', 'Position', [100, 100, 800, 600]);
    
    % UI elements
    slice_slider = uicontrol('Style', 'slider', 'Min', 1, 'Max', num_files, 'Value', 1, ...
        'SliderStep', [1/(num_files-1), 10/(num_files-1)], 'Position', [20, 550, 750, 30], ...
        'Callback', @sliceSliderCallback);
    
    slice_text = uicontrol('Style', 'text', 'String', 'Slice:', ...
        'Position', [10, 550, 40, 30]);
    
    tumor_checkbox = uicontrol('Style', 'checkbox', 'String', 'Show Tumor Mask', ...
        'Position', [650, 10, 150, 30], 'Callback', @tumorCheckboxCallback);
    
    % Display initial MRI slice
    displaySlice();
    
    % Callback functions
    function sliceSliderCallback(src, ~)
        current_slice = round(src.Value);
        displaySlice();
    end

    function tumorCheckboxCallback(src, ~)
        display_tumor_mask = src.Value;
        displaySlice();
    end

    function displaySlice()
        % Load MRI data and tumor mask
        file_path = fullfile(directory, files(current_slice).name);
        mri_data = h5read(file_path, '/mri_data');
        tumor_mask = h5read(file_path, '/tumor_mask');
        
        % Display MRI slice
        imshow(mri_data, []);
        title(sprintf('MRI Slice %d', current_slice));
        
        % Overlay tumor mask if selected
        if display_tumor_mask
            hold on;
            contour(tumor_mask, 'r');
            hold off;
        end
    end

end