function visualizeMRI
    
    fig = uifigure('Name', 'MRI Analyzer', 'Position', [100 100 800 500]);

    loadDirButton = uibutton(fig, 'Text', 'Load Slice Directory', 'Position', [50 450 150 30], 'ButtonPushedFcn', @loadSliceDirectory); %#ok<*NASGU>
    channelDropdownLabel = uilabel(fig, 'Text', 'Channel:', 'Position', [250 480 60 15]);
    channelDropdown = uidropdown(fig, 'Items', {'T1', 'T1Gd', 'T2', 'T2-FLAIR'}, 'Position', [250 450 100 30], 'ValueChangedFcn', @changeChannel);
    annotationDropdownLabel = uilabel(fig, 'Text', 'Annotation:', 'Position', [400 480 80 15]);
    annotationDropdown = uidropdown(fig, 'Items', {'On', 'Off'}, 'Position', [400 450 100 30], 'ValueChangedFcn', @toggleAnnotation);
    sliceSliderLabel = uilabel(fig, 'Text', 'Slice:', 'Position', [50 415 50 15]);
    sliceSlider = uislider(fig, 'Limits', [0 154], 'Position', [110 410 640 3], 'Value', 1, 'ValueChangedFcn', @updateSlice);
    conventionalButton = uibutton(fig, 'Text', 'Extract Conventional Features', 'Position', [50 350 200 30], 'ButtonPushedFcn', @extractConventionalFeatures);
    radiomicButton = uibutton(fig, 'Text', 'Extract Radiomic Features', 'Position', [300 350 200 30], 'ButtonPushedFcn', @extractRadiomicFeatures);
    svmButton = uibutton(fig, 'Text', 'Start SVM', 'Position', [700 450 80 30], 'ButtonPushedFcn', @startSVM);

    ax = uiaxes(fig, 'Position', [100 100 600 250]);

    maxTumorAreaLabel = uilabel(fig, 'Text', '', 'Position', [50 50 200 15]);
    maxTumorDiameterLabel = uilabel(fig, 'Text', '', 'Position', [50 30 200 15]);
    outerLayerInvolvementLabel = uilabel(fig, 'Text', '', 'Position', [50 10 200 15]);
    testDataPercentageLabel = uilabel(fig, 'Text', '', 'Position', [50 110 200 15]);
    validationPercentageLabel = uilabel(fig, 'Text', '', 'Position', [50 90 200 15]);
    hiddenPercentageLabel = uilabel(fig, 'Text', '', 'Position', [50 70 200 15]);

    topLabel = uilabel(fig, 'Text', '', 'Position', [300 50 200 15]);
    debuglabel = uilabel(fig, 'Text', '', 'Position', [300 30 200 15]);
    debuglabel.WordWrap = 'on';
    
    currentDirectory = '';
    currentChannel = 'T1';
    currentSlice = 1;
    currentVolume = -1; 

    function loadSliceDirectory(~, ~)
        directory = uigetdir();
        if directory == 0
            return;
        end

        disp(['Selected directory: ' directory]);
        currentDirectory = directory;

        [~, currentVolumeStr, ~] = fileparts(directory);
        currentVolume = str2double(strrep(currentVolumeStr, 'volume_', ''));
        
        updateImages(); 
    end
    
    function startSVM(~, ~)
        data = readtable('radiomic_table_testData.csv');
        test_dataVal = readtable('radiomic_table_validation.csv');         
        testDataHidden = readtable('radiomic_table_hidden.csv');

        featuresToRemove = {'SurfaceAreaMesh3D', 'MeanIntensity3D', 'IntensitySkewness3D', 'maxTumorArea'};
        
        data = data(:, featuresToRemove);
        test_dataVal = test_dataVal(:, featuresToRemove);
        testDataHidden = testDataHidden(:, featuresToRemove);

        
        features = data{:, 2:end-1};
        features = normalize(features);
        testFeaturesVal = test_dataVal{:, 2:end-1};        
        testFeaturesVal = normalize(testFeaturesVal);
        testFeaturesHidden = testDataHidden{:, 2:end-1};
        testFeaturesHidden = normalize(testFeaturesHidden);


        labels = data{:, end};
        trueLabelVal = test_dataVal{:, end};
        trueLabelHidden = testDataHidden{:, end};
        
        topLabel.Text = '';
        debuglabel.Text = 'Starting SVM training...';
        drawnow;
        
        cv = cvpartition(labels, 'KFold', 5);
        opts = struct('Optimizer', 'gridsearch', 'ShowPlots', false, 'Verbose', 1, 'AcquisitionFunctionName', 'expected-improvement-plus', 'MaxObjectiveEvaluations', 100);
        
        svm_model = fitcecoc(features, labels, 'OptimizeHyperparameters', 'all', 'HyperparameterOptimizationOptions', opts);

        topLabel.Text = '';
        debuglabel.Text = 'SVM training completed. Now predicting.';
        drawnow;
        
        predicted_labelsVal = predict(svm_model, testFeaturesVal);
        predicted_labelsHidden = predict(svm_model, testFeaturesHidden);
        predicted_labelsTest = predict(svm_model, features);
        


        accuracyHidden = sum(predicted_labelsHidden == trueLabelHidden) / numel(predicted_labelsHidden);
        accuracyVal = sum(predicted_labelsVal == trueLabelVal) / numel(predicted_labelsVal);
        accuracyTest = sum(predicted_labelsTest == labels) / numel(predicted_labelsTest);
        
        testDataPercentageLabel.Text = ['Test Accuracy: ' num2str(accuracyTest*100) '%'];
        hiddenPercentageLabel.Text = ['Hidden Accuracy: ' num2str(accuracyHidden*100) '%'];
        validationPercentageLabel.Text = ['Validation Accuracy: ' num2str(accuracyVal*100) '%'];
    end

    function gliomaGrade = gradeGlioma(vol)
        if vol > 259 && vol < 336
            gliomaGrade = 1;
            return;
        end
        gliomaGrade = 0;
    end


    function changeChannel(~, ~)
        currentChannel = channelDropdown.Value;
        disp(['Channel changed to: ' currentChannel]);
        updateImages();
    end

    function toggleAnnotation(~, ~)
        disp('Annotation toggled');
        updateImages();
    end

    function extractConventionalFeatures(~, ~)
        if currentVolume ~= -1
            topLabel.Text = '';
            debuglabel.Text = 'Extracting conventional features...';
            drawnow;
            [maxTumorArea, maxTumorDiameter, outerLayerInvolvement, sliceID] = calculateConventionalFeatures(currentDirectory, currentVolume);
            maxTumorAreaLabel.Text = ['Max Tumor Area: ' num2str(maxTumorArea) ', (ID: ' num2str(sliceID) ')'];
            maxTumorDiameterLabel.Text = ['Max Tumor Diameter: ' num2str(maxTumorDiameter)];
            outerLayerInvolvementLabel.Text = ['Outer Layer Involvement: ' num2str(outerLayerInvolvement) '%'];
        end
        mainDir = uigetdir();
        if mainDir == 0
            debuglabel.Text = 'User cancelled extraction';
            drawnow;
            return;
        end
        topLabel.Text = '';
        debuglabel.Text = 'EXTRACTING CONVENTIONAL FEATURES';
        drawnow;
        subfolders = dir(fullfile(mainDir, 'volume_*'));
        subfolders = subfolders([subfolders.isdir]); 
        subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));
        allResults = [];
        
        for i = 1:numel(subfolders)
            directory = fullfile(mainDir, subfolders(i).name);
            topLabel.Text = 'Extracting Conventional Features';
            debuglabel.Text = ['from ' subfolders(i).name];
            drawnow;
            [~, currentVolumeStr, ~] = fileparts(directory);
            volume = str2double(strrep(currentVolumeStr, 'volume_', ''));

            [maxTumorArea, maxTumorDiameter, outerLayerInvolvement, ~] = calculateConventionalFeatures(directory, volume);
            gliomaGrade = gradeGlioma(volume);
            volumeResults = [volume, maxTumorArea, maxTumorDiameter, outerLayerInvolvement, gliomaGrade];
            if maxTumorArea ~= -1
                allResults = [allResults; volumeResults];
            end
        end

        csvFilename = 'conventional_features.csv';
        columnTitles = ["Volume", "TumorArea", "TumorDiameter", "OuterLayerInvolvement", 'GliomaGrade(LGG=1)'];
        writematrix(columnTitles, csvFilename, 'Delimiter', ',');
        dlmwrite(csvFilename, allResults, '-append', 'Delimiter', ','); 
        topLabel.Text = 'Conventional Features';
        debuglabel.Text = ['saved to ' csvFilename];
        drawnow;
    end

    function convertH5toNii(directory, type, name)
        files = dir(fullfile(directory, '*.h5'));
        imageDataAll = zeros(240, 240, numel(files));
        for i = 1:numel(files)
            filename = fullfile(directory, files(i).name);
            imageData = h5read(filename, type);
            imageDataFirstSet = imageData(1, :, :);
            imageDataAll(:, :, i) = imageDataFirstSet;
        end
        niftiwrite(imageDataAll, fullfile(directory, name));
    end


    function extractRadiomicFeatures(~, ~)
        mainDir = uigetdir();
        if mainDir == 0
            topLabel.Text = '';
            debuglabel.Text = 'User cancelled extraction';
            drawnow;
            return;
        end
        topLabel.Text = '';
        debuglabel.Text = 'EXTRACTING RADIOMIC FEATURES';
        drawnow;
        subfolders = dir(fullfile(mainDir, 'volume_*'));
        subfolders = subfolders([subfolders.isdir]); 
        subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));
        allResults = [];

        for i = 1:numel(subfolders)
            directory = fullfile(mainDir, subfolders(i).name);
            topLabel.Text = 'Extracting Radiomic Features';
            debuglabel.Text = ['from ' subfolders(i).name];
            drawnow;
            [~, currentVolumeStr, ~] = fileparts(directory);
            volume = str2double(strrep(currentVolumeStr, 'volume_', ''));
            
            convertH5toNii(directory, '/image', 'output.nii');
            convertH5toNii(directory, '/mask', 'mask.nii')
            data = medicalVolume(fullfile(directory, 'output.nii'));
            mask = medicalVolume(fullfile(directory, 'mask.nii'));
            R = radiomics(data, mask);
            S = shapeFeatures(R);
            I = intensityFeatures(R);
            T = textureFeatures(R);
            maxTumorArea = -1;
            maxTumorDiameter = -1;
            outerLayerInvolvement = -1;
            sliceID = -1;
            [maxTumorArea, maxTumorDiameter, outerLayerInvolvement, ~] = calculateConventionalFeatures(directory, volume);
            gliomaGrade = gradeGlioma(volume);
    
            selectedFeaturesS = S(:, {'LabelID', 'VolumeMesh3D', 'SurfaceAreaMesh3D', 'Sphericity3D', ...
                                     'VolumeDensityAABB_3D', 'MajorAxisLength3D', 'MinorAxisLength3D', ...
                                     'Elongation3D', 'Flatness3D', 'IntegratedIntensity3D'});
            selectedFeaturesI = I(:, {'MeanIntensity3D', 'MedianIntensity3D', 'MinimumIntensity3D', 'MaximumIntensity3D', ...
                                     'IntensityVariance3D', 'IntensitySkewness3D', 'IntensityKurtosis3D', ...
                                     'IntensityRange3D', 'IntensityInterquartileRange3D', 'RootMeanSquare3D'});
            selectedFeaturesT = T(:, {'JointEntropyAveraged3D', 'AngularSecondMomentAveraged3D', 'ContrastAveraged3D', 'DissimilarityAveraged3D', ...
                                     'ClusterTendencyAveraged3D', 'ClusterShadeAveraged3D', 'ClusterProminenceAveraged3D', ...
                                     'InverseDifferenceAveraged3D', 'CorrelationAveraged3D', 'AutoCorrelationAveraged3D'});

            selectedFeaturesS.LabelID = volume;
            selectedFeaturesT.maxTumorArea = maxTumorArea;
            selectedFeaturesT.maxTumorDiameter = maxTumorDiameter;
            selectedFeaturesT.outerLayerInvolvement = outerLayerInvolvement;
            selectedFeaturesT.gliomaGrade = gliomaGrade;
            allData = [selectedFeaturesS, selectedFeaturesI, selectedFeaturesT];
            allResults = [allResults; allData];
        end
        
        writetable(allResults, 'radiomic_table.csv');
        topLabel.Text = 'Radiomic Features saved';
        debuglabel.Text = 'as radiomic_features.csv';
        drawnow;
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
            imageData = h5read(filename, '/image');
            maskData = h5read(filename, '/mask');
            colors = {'r', 'g', 'b'};
    
            disp(['Loaded image data size: ' num2str(size(imageData))]);
            disp(['Image data class: ' class(imageData)]);
    
            channelIndex = getChannelIndex(currentChannel);
            imagesc(ax, squeeze(imageData(channelIndex, :, :)));
            colormap(ax, gray);
            axis(ax, 'image');
            hold(ax, 'on'); 
            
    
            
            if strcmp(annotationDropdown.Value, 'On')
                for i = 1:numel(colors)
                    try
                        mask = squeeze(maskData(i, :, :));
                        contour(ax, mask, colors{i});
                    catch
                        disp(['Error reading mask data for mask ' num2str(i)]);
                    end
                end
            end


            hold(ax, 'off');
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
        channelIndices = containers.Map({'T2-FLAIR', 'T1', 'T1Gd', 'T2'}, {1, 2, 3, 4});
        index = channelIndices(channel);
    end

    function updateSlice(src, ~)
        currentSlice = round(src.Value);
        disp(['Slice changed to: ' num2str(currentSlice)]);
        updateImages();
    end

    function [maxTumorArea, maxTumorDiameter, outerLayerInvolvement, sliceID] = calculateConventionalFeatures(dir, vol)
        results = [];
        outerLayerThickness = 5;

        for i = 1:154
            try
                filename = fullfile(dir, sprintf('volume_%d_slice_%d.h5', vol, i));
                if ~exist(filename, 'file')
                    disp(['File not found: ' filename]);
                    throw(MException('MATLAB:FileNotFound', 'File not found'));
                end

                maskData = h5read(filename, '/mask');
                count = 0;
                maxDistance = 0;

                for j = 1:3
                    mask = squeeze(maskData(j, :, :));
                    [rows, cols] = find(mask);
                    numPixels = numel(rows);

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

                
                
                [numberOfOuterLayerPixels, numberOfOverLappingTumorPixels] = involvement(dir, vol, i);

                results = [results; vol, i, count, maxDistance, numberOfOuterLayerPixels, numberOfOverLappingTumorPixels]; %#ok<AGROW>

            catch ME
                disp(['Error reading mask data: ' ME.message ME.stack]);
                maxTumorArea = -1;
                maxTumorDiameter = -1;
                outerLayerInvolvement = -1;
                sliceID = -1;
                return;
            end
        end
        
        maxTumorArea = max(results(:, 3));
        maxTumorDiameter = max(results(:, 4));
        totalOuterLayerPixels = sum(results(:, 5));
        totalTumorLayerPixels = sum(results(:, 6));
        outerLayerInvolvement = (totalTumorLayerPixels/totalOuterLayerPixels) * 100;
        sliceID = find(results(:, 3) == maxTumorArea, 1);
    end
end



function [numberOfOuterLayerPixels, numberOfOverLappingTumorPixels] = involvement(dir, vol, slice)

    try
        filename = fullfile(dir, sprintf('volume_%d_slice_%d.h5', vol, slice));
        if ~exist(filename, 'file')
            disp(['File not found: ' filename]);
            throw(MException('MATLAB:FileNotFound', 'File not found'));
        end
    catch ME
        disp(['File not found INVOLVEMENT(): ' ME.message]);
    end

    try
        calcOuterLayer = 0;
        calcTumorLayer = 0;
        count = 0;
        imageData = h5read(filename, '/image');
        maskData = h5read(filename, '/mask');
        se = strel('square', 3);


        image = squeeze(imageData(1, :, :));
        image = imbinarize(image);
        imageS = bwconvhull(image, "objects");
        
        erImage = imerode(imageS, se);
        for i = 1:5
            erImage = imerode(erImage, se);
        end 

        finalImage = image - erImage;
        finalImage = imbinarize(finalImage);
        

        calcOuterLayer = sum(finalImage(:));        
        for i= 1:3
            mask = squeeze(maskData(i, :, :));
            mask = imbinarize(mask);
            bitImage = bitand(finalImage, mask);
            count = sum(bitImage(:));
            calcTumorLayer = calcTumorLayer + count;
        end
    catch ME
        disp(['Something wrong ' ME.message]);
        calcOuterLayer = 1;
        calcTumorLayer = 1;
    end
    numberOfOuterLayerPixels = calcOuterLayer;
    numberOfOverLappingTumorPixels = calcTumorLayer; 
end