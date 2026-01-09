function HoriStitchBigFile(info_IO_path, info_file_path, img_file_type, img_path, img_save_path, ch_num, ch_th, img_data_type, move_ratio)
% HoriStitchBigFile: Performs horizontal stitching for memory-intensive large image files.
% The core strategy is to down-sample images upon import to reduce memory consumption.

    % --- 1. Initialization ---
    if ~exist(img_save_path, 'dir'), mkdir(img_save_path); end
    fprintf('Starting Big File horizontal stitching process...\n');

    % --- 2. Metadata Input ---
    if strcmpi(img_file_type, 'tif')
        % Big file mode typically relies on a simple text file for position info.
        [dim_elem_num, dim_len, voxel_len, tile_num, tile_pos] = stitchlib.InfoIO.get_img_txt_info(img_path, info_file_path, ch_num);
    else
        error('Big File mode currently only supports the TIF file type.');
    end
    
    img_name_list = stitchlib.FileRename.get_img_name_list(img_path, img_file_type);
    fprintf('Found %d image files.\n', length(img_name_list));
    
    % --- 3. Adjacency Detection and Stitching Preparation ---
    tile_contact = stitchlib.TileCont.judge_tile_cont(dim_len, tile_pos);
    fprintf('Tile adjacency relationships have been calculated.\n');

    voxel_range = int64(ceil(double(dim_elem_num) .* move_ratio));
    fprintf('Voxel search range: [%d, %d, %d]\n', voxel_range(1), voxel_range(2), voxel_range(3));
    
    % One less pyramid level is needed since we down-sample once on import.
    pyr_down_times = stitchlib.ParaEsti.pyr_down_time_esti(dim_elem_num, 100*100*50) - 1;
    fprintf('Total down-sampling steps: %d\n', pyr_down_times + 1);
    
    % --- 4. Serial Pairwise Stitching (avoids parallelization to control memory) ---
    stitch_pairs_indices = find(triu(tile_contact, 1));
    [pair_i, pair_j] = ind2sub(size(tile_contact), stitch_pairs_indices);
    
    num_pairs = length(pair_i);
    results = cell(num_pairs, 1);
    
    tic;
    % Use a cache to avoid re-reading and re-processing the same down-sampled tile.
    img_cache = containers.Map('KeyType', 'double', 'ValueType', 'any');

    for k = 1:num_pairs
        i = pair_i(k);
        j = pair_j(k);
        fprintf('Stitching tile pair %d and %d...\n', i, j);
        
        % Use cache to avoid re-reading files.
        if isKey(img_cache, i)
            img1 = img_cache(i);
        else
            img1 = import_img_one_tile_big(img_path, img_name_list, i-1, ch_num, ch_th, dim_elem_num, img_data_type);
            img_cache(i) = img1;
        end

        if isKey(img_cache, j)
            img2 = img_cache(j);
        else
            img2 = import_img_one_tile_big(img_path, img_name_list, j-1, ch_num, ch_th, dim_elem_num, img_data_type);
            img_cache(j) = img2;
        end
        
        % Perform stitching on the down-sampled data.
        dim_elem_num_ds = [size(img1,2), size(img1,1), size(img1,3)]; % X, Y, Z
        
        [shift, loss] = one_stitch_big(img1, img2, tile_pos([i,j],:)/2, dim_elem_num_ds, dim_len/2, voxel_len, floor(double(voxel_range)/2), pyr_down_times);
        results{k} = {i, j, shift * 2, loss}; % Scale shift back to original resolution.
    end
    fprintf('Pairwise stitching took %.2f seconds.\n', toc);
    
    % --- 5. Update Global Positions and Export ---
    % Calls the same helper functions from HoriStitch.m
    [tile_shift_arr, tile_shift_loss] = get_stitch_result(results, tile_num, voxel_len);
    [tile_pos_stitch, ~] = update_strip_pos_by_MST(tile_pos, tile_shift_arr, tile_shift_loss);
    
    [axis_range, voxel_num] = stitchlib.AxisRange.calc_axis_range(tile_pos_stitch, dim_elem_num, voxel_len);
    first_last_index = [1, voxel_num(3)]; % Big file mode assumes all Z-layers are used.
    
    % Exporting requires reading the ORIGINAL full-resolution images.
    export_img_hori_stit_big(img_path, img_save_path, img_name_list, ch_num, img_file_type, img_data_type, dim_elem_num, dim_len, voxel_len, tile_pos_stitch, axis_range, first_last_index);

    fprintf('Big File stitching process complete.\n');
end

% --- Internal Helper Functions for Big File Mode ---

function voxel_array = import_img_one_tile_big(img_path, file_list, tile_idx, ch_num, ch_th, dim_elem_num, img_data_type)
% Reads and down-samples on the fly to save memory.
    
    z_dim_ds = ceil(dim_elem_num(3) / 2);
    
    % Read the first image to determine the down-sampled XY size.
    first_img_idx_in_list = dim_elem_num(3) * (tile_idx * ch_num + ch_th) + 1;
    first_img_name = fullfile(img_path, file_list{first_img_idx_in_list});
    img_ds = impyramid(imread(first_img_name), 'reduce');
    
    voxel_array = zeros(size(img_ds,1), size(img_ds,2), z_dim_ds, img_data_type);
    voxel_array(:,:,1) = img_ds;
    
    z_ds_idx = 2;
    % Start from the 3rd Z-slice (index 2), step by 2.
    for j = 2:2:dim_elem_num(3)-1 
        img_idx_in_list = dim_elem_num(3) * (tile_idx * ch_num + ch_th) + j + 1;
        one_img_name = fullfile(img_path, file_list{img_idx_in_list});
        voxel_array(:, :, z_ds_idx) = impyramid(imread(one_img_name), 'reduce');
        z_ds_idx = z_ds_idx + 1;
    end
end

function [shift, loss_max] = one_stitch_big(img1, img2, tile_pos_ds, dim_elem_num_ds, dim_len_ds, voxel_len, voxel_range_ds, pyr_down_times)
% A wrapper for one_stitch that works on pre-downsampled data.
% The logic is identical to the standard one_stitch, just with different input variables.
    [shift, loss_max] = one_stitch(img1, img2, tile_pos_ds, dim_elem_num_ds, dim_len_ds, voxel_len, voxel_range_ds, false, pyr_down_times, 3);
end

function export_img_hori_stit_big(img_path, img_save_path, img_name_list, ch_num, ~, img_data_type, dim_elem_num, dim_len, voxel_len, tile_pos, axis_range, first_last_index)
% Exports the result for Big File mode by reading full-resolution images.
    tile_num = size(tile_pos, 1);
    voxel_num = int64(round((axis_range(:, 2) - axis_range(:, 1))' ./ voxel_len));

    img_num = 0;
    for j = first_last_index(1):first_last_index(2) % Iterate through Z-slices
        for ch_th = 0:ch_num-1
            final_slice = zeros(voxel_num(2), voxel_num(1), img_data_type);
            this_z_um = axis_range(3, 1) + voxel_len(3) * (j-1);
            
            for k = 1:tile_num
                if this_z_um < tile_pos(k, 3) || this_z_um >= tile_pos(k, 3) + dim_len(3)
                    continue;
                end
                z_th = round((this_z_um - tile_pos(k, 3)) / voxel_len(3));
                
                x_th = round((tile_pos(k, 1) - axis_range(1, 1)) / voxel_len(1)) + 1;
                y_th = round((tile_pos(k, 2) - axis_range(2, 1)) / voxel_len(2)) + 1;
                
                % Read the original, full-resolution 2D image from disk.
                img_idx_in_list = dim_elem_num(3) * ((k-1) * ch_num + ch_th) + z_th + 1;
                img_2d = imread(fullfile(img_path, img_name_list{img_idx_in_list}));
                
                % Paste onto the final canvas (no blending in this simplified export).
                final_slice(y_th:y_th+dim_elem_num(2)-1, x_th:x_th+dim_elem_num(1)-1) = img_2d;
            end
            
            imwrite(final_slice, fullfile(img_save_path, sprintf('z%.4d_ch%.2d.tif', img_num, ch_th)));
        end
        img_num = img_num + 1;
    end
end