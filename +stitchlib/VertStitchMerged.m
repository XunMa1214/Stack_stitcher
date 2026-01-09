% stitchlib.VertStitchMerged.m (Corrected and Improved)

function VertStitchMerged(file_path, img_save_path, img_name_format, ~, img_name, ch_num, ch_th, img_file_type, img_data_type, overlap_ratio, if_rename_file, pro_num, ~, ~)
% VertStitchMerged: Corrected version to faithfully replicate Python's vertical stitching logic.

    % --- 1. Initialization ---
    if ~exist(img_save_path, 'dir'), mkdir(img_save_path); end

    % Setup parallel pool
    if isempty(gcp('nocreate'))
        c = parcluster('local');
        if pro_num == -1
            num_workers_to_request = max(1, floor(c.NumWorkers / 2));
        else
            num_workers_to_request = min(c.NumWorkers, pro_num);
        end
        fprintf('Starting a parallel pool with %d workers...\n', num_workers_to_request);
        parpool(num_workers_to_request);
    end

    dir_info = dir(file_path);
    file_list = {dir_info.name};
    % Filter for directories, excluding '.' and '..'
    file_list = file_list([dir_info.isdir] & ~ismember(file_list, {'.', '..'}));
    layer_num = length(file_list);

    % Initialize arrays with data types matching Python
    xy_shift_array = zeros(layer_num, 2, 'double');   % Python: float64
    axis_range_array = zeros(layer_num, 2, 2, 'int64');
    first_last_index = zeros(layer_num, 2, 'int64');
    dim_elem_num = zeros(layer_num, 3, 'int64');

    % --- 2. Main Loop for Layer-by-Layer Alignment ---
    for i = 1:(layer_num-1)
        tic;
        fprintf('====================================================\n');
        fprintf('Aligning layer %d and %d...\n', i, i+1);
        img_path1 = fullfile(file_path, file_list{i});
        img_path2 = fullfile(file_path, file_list{i+1});

        % Get image dimensions and file counts
        file_list1 = stitchlib.FileRename.get_img_name_list(img_path1, img_file_type);
        file_list2 = stitchlib.FileRename.get_img_name_list(img_path2, img_file_type);
        dim_elem_num(i, 3) = int64(floor(length(file_list1) / ch_num));
        dim_elem_num(i+1, 3) = int64(floor(length(file_list2) / ch_num));

        % Rename files if requested
        if if_rename_file
            if i == 1
                stitchlib.FileRename.rename_file_Z_stit(img_name_format, img_path1, img_name, dim_elem_num(i, 3), ch_num, img_file_type);
            end
            stitchlib.FileRename.rename_file_Z_stit(img_name_format, img_path2, img_name, dim_elem_num(i+1, 3), ch_num, img_file_type);
        end
        
        % Initialize dimensions and axis for the first layer
        if i == 1
            % Read the last image of the first stack to get dimensions
            img1_first = stitchlib.ImgIO.import_img_2D(img_name_format, img_path1, img_name, dim_elem_num(i, 3) - 1, ch_th, img_file_type, img_data_type);
            [h, w] = size(img1_first);
            dim_elem_num(i, 1:2) = [w, h];
            first_last_index(i, :) = [1, dim_elem_num(i, 3)]; % Use 1-based index for MATLAB
            axis_range_array(i, 1, :) = [0, w]; 
            axis_range_array(i, 2, :) = [0, h];
        end
        % Get dimensions for the next layer
        img2_first = stitchlib.ImgIO.import_img_2D(img_name_format, img_path2, img_name, 0, ch_th, img_file_type, img_data_type);
        [h, w] = size(img2_first);
        dim_elem_num(i+1, 1:2) = [w, h];
        first_last_index(i+1, :) = [1, dim_elem_num(i+1, 3)];
        
        % Define overlap search range
        ovl_num = ceil(min(dim_elem_num(i, 3), dim_elem_num(i+1, 3)) * overlap_ratio);
        step1 = 5; step2 = 5;
        
        fprintf('Pass 1: Sparse search...\n');
        % Define Z-indices for sparse search (using 0-based for logic, convert for file access later)
        z_indices1 = (dim_elem_num(i,3)-1) : -step1 : max(0, dim_elem_num(i,3) - ovl_num - 1);
        z_indices2 = 0 : step2 : min(ovl_num-1, dim_elem_num(i+1,3)-1);
        [~, ~, xy_shift_max, index1, index2] = run_stitching_pass(img_path1, img_path2, z_indices1, z_indices2, img_name_format, img_name, ch_th, img_file_type, img_data_type);
        fprintf('\nSparse search result - Shift: [%d, %d], Z-indices: [%d, %d]\n', xy_shift_max(1), xy_shift_max(2), index1, index2);
        
        fprintf('\nPass 2: Dense search...\n');
        z_indices1_pass2 = index1; % Only check the best Z from the previous pass
        z_indices2_pass2 = max(0, index2-step2+1) : min(index2+step2, dim_elem_num(i+1, 3)-1);
        [~, loss_max, xy_shift_max, index1, index2] = run_stitching_pass(img_path1, img_path2, z_indices1_pass2, z_indices2_pass2, img_name_format, img_name, ch_th, img_file_type, img_data_type);
        fprintf('\nFinal Alignment - Shift: [%d, %d], Loss: %.4f, Z-indices: [%d, %d]\n', xy_shift_max(1), xy_shift_max(2), loss_max, index1, index2);

        % Update results (using 1-based indexing for MATLAB arrays)
        first_last_index(i, 2) = index1 + 1; % Convert 0-based result to 1-based index
        first_last_index(i+1, 1) = index2 + 1; % Convert 0-based result to 1-based index
        xy_shift_array(i+1, :) = double(xy_shift_max);
        
        % Update axis ranges based on the calculated shift
        axis_range_array(i+1, :, 1) = axis_range_array(i, :, 1) - xy_shift_max;
        axis_range_array(i+1, :, 2) = axis_range_array(i+1, :, 1) + dim_elem_num(i+1, 1:2);
        
        fprintf('Layer %d alignment took %.2f seconds.\n', i, toc);
    end
    
    % --- 3. Export Final Stitched Images ---
    stitchlib.ImgIO.export_img_vert_stit(file_path, file_list, img_save_path, axis_range_array, first_last_index, img_name_format, img_name, ch_num, img_file_type, img_data_type);
end

% --- Helper function for a single stitching pass ---
function [res_list, loss_max, xy_shift_max, index1, index2] = run_stitching_pass(path1, path2, z_indices1, z_indices2, name_format, name, ch, type, dtype)
    % Create all pairs of Z-indices to be tested
    pairs = [];
    for z1 = z_indices1
        for z2 = z_indices2
            pairs = [pairs; z1, z2];
        end
    end
    
    num_pairs = size(pairs, 1);
    if num_pairs == 0
        res_list={}; loss_max=-Inf; xy_shift_max=int64([0,0]); index1=-1; index2=-1; return;
    end
    
    results = cell(num_pairs, 1);
    
    % Setup a data queue for progress display from parfor
    data_queue = parallel.pool.DataQueue; 
    afterEach(data_queue, @display_progress);
    progress_counter = 0;
    
    parfor k = 1:num_pairs
        z1 = pairs(k, 1); 
        z2 = pairs(k, 2);
        
        img1 = stitchlib.ImgIO.import_img_2D(name_format, path1, name, z1, ch, type, dtype);
        img2 = stitchlib.ImgIO.import_img_2D(name_format, path2, name, z2, ch, type, dtype);
        
        [shift, loss] = one_stitch_vert(img1, img2);
        
        % Store results in a cell array
        results{k} = {z1, z2, shift, loss};
        
        % Send data to the queue to update progress
        send(data_queue, k);
    end
    
    % Find the best result from all pairs
    [index1, index2, xy_shift_max, loss_max] = get_stitch_result_vert(results);
    res_list = results;
    
    % Nested function to display progress
    function display_progress(~)
        progress_counter = progress_counter + 1;
        fprintf('\rProcessing pair: %d / %d (%.1f%%)', progress_counter, num_pairs, (progress_counter/num_pairs)*100);
    end
end

% --- Helper function to find the best result ---
function [index1, index2, xy_shift_max, loss_max] = get_stitch_result_vert(res_list)
% **CORRECTED VERSION**
    index1 = -1; 
    index2 = -1;
    xy_shift_max = int64([0,0]);
    loss_max = -1;
    
    for k = 1:length(res_list)
        res_cell = res_list{k};
        
        % Correctly extract data from the cell array
        j_val = res_cell{1};
        k_val = res_cell{2};
        shift = res_cell{3};
        loss  = res_cell{4};
        
        if loss > loss_max
            loss_max = loss;
            xy_shift_max = shift;
            index1 = j_val;
            index2 = k_val;
        end
    end
end


% --- Helper function for a single pair alignment ---
function [xy_shift, loss] = one_stitch_vert(img1, img2)
    pyr_down_times = max(stitchlib.ParaEsti.pyr_down_time_esti(size(img1)), ...
                         stitchlib.ParaEsti.pyr_down_time_esti(size(img2)));
    
    % Pre-processing
    img1 = medfilt2(img1, [3 3]);
    img2 = medfilt2(img2, [3 3]);
    
    % Coarse alignment on down-sampled images
    img1_down = stitchlib.ImgProcess.pyr_down_img_2D(img1, pyr_down_times);
    img2_down = stitchlib.ImgProcess.pyr_down_img_2D(img2, pyr_down_times);
    [img1_down, img2_down] = stitchlib.ImgProcess.adjust_contrast(img1_down, img2_down, 10);
    
    [xy_shift, ~] = calc_xy_shift_by_SIFT(img1_down, img2_down);
    
    % Fine alignment using brute-force search
    [xy_shift, loss] = calc_xy_shift_by_BF(img1, img2, xy_shift, pyr_down_times);
end

% --- SIFT alignment function ---
function [xy_shift_max, loss_max] = calc_xy_shift_by_SIFT(img1, img2, sample_times)
    if nargin < 3, sample_times = 200; end
    loss_max = -1;
    xy_shift_max = int64([0,0]);
    
    % Convert to uint8 for SIFT
    if ~isa(img1, 'uint8'), img1 = im2uint8(img1); end
    if ~isa(img2, 'uint8'), img2 = im2uint8(img2); end
    
    points1 = detectSIFTFeatures(img1);
    points2 = detectSIFTFeatures(img2);
    [features1, valid_points1] = extractFeatures(img1, points1);
    [features2, valid_points2] = extractFeatures(img2, points2);

    if isempty(valid_points1) || isempty(valid_points2), return; end
    
    indexPairs = matchFeatures(features1, features2, 'MaxRatio', 0.75, 'Unique', true);
    if size(indexPairs, 1) < 4, return; end
    
    pts1 = valid_points1.Location(indexPairs(:, 1), :);
    pts2 = valid_points2.Location(indexPairs(:, 2), :);

    % Manual RANSAC-like process
    count = 0;
    matches_num = size(pts1, 1);
    RANSAC_num = int32(max(min(4, matches_num * 0.1), 1));
    
    while count < sample_times
        count = count + 1;
        index_list = randperm(matches_num, RANSAC_num);
        xy_shift_all = pts2(index_list, :) - pts1(index_list, :);
        
        if any(max(xy_shift_all, [], 1) - min(xy_shift_all, [], 1) > 100), continue; end
        
        xy_shift = int64(round(mean(xy_shift_all, 1)));
        
        if all(xy_shift == xy_shift_max), continue; end
        
        [ovl1, ovl2] = get_overlap_regions(img1, img2, xy_shift);
        this_loss = stitchlib.LossFunc.loss_func_z_stitch(ovl1, ovl2);
        
        if this_loss > loss_max
            loss_max = this_loss;
            xy_shift_max = xy_shift;
        end
    end
end

% --- Brute-force alignment function (Corrected) ---
function [xy_shift_max, loss_max] = calc_xy_shift_by_BF(img1, img2, xy_shift, pyr_down_times)
    % Start with the coarse shift from the SIFT alignment
    current_best_shift = int64(xy_shift); 

    for i = pyr_down_times:-1:0
        loss_max = -1.0; % Initialize max loss for the current pyramid level

        % Downsample images for the current level
        if i > 0
            img1_calc = stitchlib.ImgProcess.pyr_down_img_2D(img1, i);
            img2_calc = stitchlib.ImgProcess.pyr_down_img_2D(img2, i);
        else
            img1_calc = img1; 
            img2_calc = img2;
        end

        % Define the search center by upscaling the result from the previous level
        if i < pyr_down_times
            search_center = current_best_shift * 2;
        else
            search_center = current_best_shift;
        end
        
        % Define the search radius for the current level
        range_calc = 2 + i;
        if i == pyr_down_times, range_calc = 10; end

        % **CRITICAL FIX 1: Guarantee initialization**
        % The best shift for this level starts as the search center. This ensures
        % it always has a value, even if no better shift is found.
        level_best_shift = search_center;

        % Iterate through the search window
        for y = -range_calc:range_calc
            for x = -range_calc:range_calc
                this_xy_shift = search_center + int64([x, y]);
                [ovl1, ovl2] = get_overlap_regions(img1_calc, img2_calc, this_xy_shift);

                % Skip if the overlap is too small
                if numel(ovl1) < 256, continue; end
                
                % To speed up, analyze a max 2000x2000 region, similar to Python
                [h, w] = size(ovl1);
                y_start = max(1, floor(h/2)-999); y_end = min(h, y_start+1999);
                x_start = max(1, floor(w/2)-999); x_end = min(w, x_start+1999);
                
                this_loss = stitchlib.LossFunc.loss_func_z_stitch(ovl1(y_start:y_end, x_start:x_end), ovl2(y_start:y_end, x_start:x_end));

                if this_loss > loss_max
                    loss_max = this_loss;
                    level_best_shift = this_xy_shift;
                end
            end
        end
        
        % The best shift from this level becomes the starting point for the next
        current_best_shift = level_best_shift;
    end
    
    % **CRITICAL FIX 2: Assign final values to output arguments**
    % This ensures the function always returns the calculated values.
    xy_shift_max = current_best_shift;
end

% --- Overlap region calculation ---
function [ovl1, ovl2] = get_overlap_regions(img1, img2, shift)
    shift = double(shift); % Use double for calculations
    [h1, w1] = size(img1); [h2, w2] = size(img2);
    
    % Define the overlapping window in the coordinate system of img1
    x_overlap_start_1 = max(1, 1 - shift(1));
    x_overlap_end_1   = min(w1, w2 - shift(1));
    y_overlap_start_1 = max(1, 1 - shift(2));
    y_overlap_end_1   = min(h1, h2 - shift(2));

    % Define the overlapping window in the coordinate system of img2
    x_overlap_start_2 = max(1, 1 + shift(1));
    x_overlap_end_2   = min(w2, w1 + shift(1));
    y_overlap_start_2 = max(1, 1 + shift(2));
    y_overlap_end_2   = min(h2, h1 + shift(2));
    
    % Check for valid overlap
    if x_overlap_start_1 > x_overlap_end_1 || y_overlap_start_1 > y_overlap_end_1
        ovl1 = []; ovl2 = [];
        return;
    end
    
    ovl1 = img1(y_overlap_start_1:y_overlap_end_1, x_overlap_start_1:x_overlap_end_1);
    ovl2 = img2(y_overlap_start_2:y_overlap_end_2, x_overlap_start_2:x_overlap_end_2);
end