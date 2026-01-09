function HoriStitch(info_IO_path, info_file_path, img_file_type, img_path, img_save_path, img_name_format, img_name, ch_num, ch_th, img_data_type, ~, move_ratio, if_sparce, if_high_noise, if_rename_file, if_blend, pro_num)
% HoriStitch: Performs horizontal (XY) stitching of 3D image tiles.
% This function is the core of the horizontal stitching workflow, coordinating
% all steps from data reading to final image export.

    % --- 1. Initialization ---
    if ~exist(img_save_path, 'dir'), mkdir(img_save_path); end

    % Setup parallel pool if it doesn't exist
    if isempty(gcp('nocreate'))
        c = parcluster('local');
        if pro_num == -1
            num_workers_to_request = max(1, floor(feature('numcores') / 2));
        else
            num_workers_to_request = min(c.NumWorkers, pro_num);
        end
        fprintf('Starting a parallel pool with %d workers...\n', num_workers_to_request);
        parpool(num_workers_to_request);
    end

    % --- 2. Metadata Input ---
    fprintf('Reading image metadata...\n');
    whole_img = []; % Pre-load data for nd2/lif formats
    switch lower(img_file_type)
        case 'nd2'
            [dim_elem_num, dim_len, voxel_len, tile_num, tile_pos, img_data_type] = stitchlib.InfoIO.get_img_nd2_info(img_path);
            % For nd2/lif, the entire file might be read into memory by the Bio-Formats reader
        case 'lif'
            [dim_elem_num, dim_len, voxel_len, tile_num, tile_pos] = stitchlib.InfoIO.get_img_lif_info(img_path);
        case 'tif'
            [dim_elem_num, dim_len, voxel_len, tile_num, tile_pos] = stitchlib.InfoIO.get_img_txt_info(img_path, info_file_path, ch_num);
            if if_rename_file
                stitchlib.FileRename.rename_file(img_name_format, img_path, img_name, dim_elem_num(3), ch_num, img_file_type);
            end
        otherwise
            error('Unsupported image file type: %s', img_file_type);
    end

    % --- 3. Adjacency Detection and Stitching Preparation ---
    fprintf('Determining adjacent tiles...\n');
    tile_contact = stitchlib.TileCont.judge_tile_cont(dim_len, tile_pos, 0.8);
    
    voxel_range = int64(ceil(double(dim_elem_num) .* move_ratio));
    fprintf('Voxel search range: [%d, %d, %d]\n', voxel_range(1), voxel_range(2), voxel_range(3));
    
    pyr_down_times = stitchlib.ParaEsti.pyr_down_time_esti(dim_elem_num, 100*100*20);
    fprintf('Estimated image pyramid levels: %d\n', pyr_down_times);
    
    blur_kernel_size = 3;
    if if_high_noise, blur_kernel_size = 5; end
    
    % --- 4. Parallel Pairwise Stitching ---
    fprintf('Starting parallel computation of pairwise shifts...\n');
    
    % Get linear indices of upper triangle of the contact matrix
    stitch_pairs_indices = find(triu(tile_contact, 1)); 
    [pair_i, pair_j] = ind2sub(size(tile_contact), stitch_pairs_indices);
    
    num_pairs = length(pair_i);
    results = cell(num_pairs, 1);
    
    parfor k = 1:num_pairs
        i = pair_i(k);
        j = pair_j(k);
        
        fprintf('Stitching tile pair: %d and %d\n', i, j);
        
        img1 = stitchlib.ImgIO.import_img_one_tile_stack(img_name_format, img_path, img_name, i-1, ch_th, dim_elem_num, img_file_type, img_data_type);
        img2 = stitchlib.ImgIO.import_img_one_tile_stack(img_name_format, img_path, img_name, j-1, ch_th, dim_elem_num, img_file_type, img_data_type);
        
        pair_pos = tile_pos([i, j], :);
        [shift, loss] = one_stitch(img1, img2, pair_pos, dim_elem_num, dim_len, voxel_len, voxel_range, if_sparce, pyr_down_times, blur_kernel_size);
        results{k} = {i, j, shift, loss};
    end

    % --- 5. Global Position Update using MST ---
    fprintf('Aggregating results and computing global positions using MST...\n');
    [tile_shift_arr, tile_shift_loss] = get_stitch_result(results, tile_num, voxel_len);
    [tile_pos_stitch, tile_refer_id] = update_strip_pos_by_MST(tile_pos, tile_shift_arr, tile_shift_loss);

    % --- 6. Final Canvas Calculation and Metadata Save ---
    fprintf('Calculating final image dimensions...\n');
    [axis_range, voxel_num] = stitchlib.AxisRange.calc_axis_range(tile_pos_stitch, dim_elem_num, voxel_len);
    first_last_index = stitchlib.AxisRange.find_first_last_index(tile_pos_stitch, dim_elem_num, axis_range, voxel_len, voxel_num);
    
    fprintf('Saving metadata...\n');
    info_struct.img_file_type = img_file_type;
    info_struct.ch_num = ch_num;
    info_struct.img_data_type = img_data_type;
    info_struct.dim_elem_num = dim_elem_num;
    info_struct.dim_len = dim_len;
    info_struct.voxel_len = voxel_len;
    info_struct.tile_pos = tile_pos_stitch;
    info_struct.tile_shift_arr = tile_shift_arr;
    info_struct.tile_shift_loss = tile_shift_loss;
    info_struct.tile_refer_id = tile_refer_id;
    info_struct.first_last_index = first_last_index;
    stitchlib.InfoIO.save_info_to_xml(fullfile(info_IO_path,'meta.xml'), info_struct);

    % --- 7. Export Final Image Slices ---
    fprintf('Exporting stitched image slices...\n');
    stitchlib.ImgIO.export_img_hori_stit(img_path, img_save_path, img_name_format, img_name, ch_num, ...
        img_file_type, img_data_type, dim_elem_num, dim_len, voxel_len, tile_pos_stitch, ...
        axis_range, first_last_index, 'tif', if_blend);
        
    fprintf('Horizontal stitching complete.\n');
end

% --- Internal Helper Functions ---

function [shift, loss_max] = one_stitch(img1, img2, tile_pos, dim_elem_num, dim_len, voxel_len, voxel_range, if_sparce, pyr_down_times, blur_kernel_size)
% Performs coarse-to-fine alignment for a single pair of images.
    img1_filt = medfilt3(img1, [blur_kernel_size, blur_kernel_size, 1]);
    img2_filt = medfilt3(img2, [blur_kernel_size, blur_kernel_size, 1]);

    shift_s = [0, 0, 0]; 
    loss_max = -1;

    for pdt = pyr_down_times:-1:0
        if pdt == pyr_down_times
            shift_pd = [0, 0, 0];
            search_range_pd = int64(round(double(voxel_range) / (2^pdt)));
        else
            shift_pd = shift_s * 2;
            search_range_pd = [2, 2, 0]; % Z-shift is fixed after the first coarse alignment.
        end

        if pdt > 0
            img1_pd = stitchlib.ImgProcess.pyr_down_img(img1_filt, pdt);
            img2_pd = stitchlib.ImgProcess.pyr_down_img(img2_filt, pdt);
            down_multi = [size(img1_pd,2), size(img1_pd,1), size(img1_pd,3)] ./ double([size(img1,2), size(img1,1), size(img1,3)]);
        else
            img1_pd = img1_filt; img2_pd = img2_filt;
            down_multi = [1, 1, 1];
        end
        
        best_shift_current_level = shift_pd;
        x_sr = shift_pd(1); y_sr = shift_pd(2); z_sr = shift_pd(3);

        for x = (x_sr - search_range_pd(1)) : (x_sr + search_range_pd(1))
        for y = (y_sr - search_range_pd(2)) : (y_sr + search_range_pd(2))
        for z = (z_sr - search_range_pd(3)) : (z_sr + search_range_pd(3))
            current_shift_voxels = [x, y, z];
            this_tile_pos = tile_pos;
            this_tile_pos(2, :) = this_tile_pos(2, :) + (double(current_shift_voxels) .* voxel_len) ./ down_multi;
            
            pd_dim_elem = [size(img1_pd,2), size(img1_pd,1), size(img1_pd,3)];
            pd_dim_len = double(pd_dim_elem) .* (voxel_len ./ down_multi);
            border = stitchlib.ImgBorder.get_2img_border(pd_dim_elem, pd_dim_len, voxel_len./down_multi, this_tile_pos);
            
            if isempty(border), continue; end
            
            [ovl1_list, ovl2_list] = stitchlib.ImgOvl.get_ovl_img(img1_pd, img2_pd, border, if_sparce);
            this_loss = stitchlib.LossFunc.loss_func_for_list(ovl1_list, ovl2_list);

            if this_loss > loss_max
                loss_max = this_loss;
                best_shift_current_level = current_shift_voxels;
            end
        end, end, end
        shift_s = best_shift_current_level;
        fprintf('  Pyramid Level %d, Best Shift: [%d, %d, %d], NCC: %.4f\n', pdt, shift_s(1), shift_s(2), shift_s(3), loss_max);
    end

    shift = shift_s;
    if loss_max <= 0.6 || any(abs(shift) > double(voxel_range))
        shift = [0,0,0]; 
        loss_max = -1;
    end
end

function [tile_shift_arr, tile_shift_loss] = get_stitch_result(results, tile_num, voxel_len)
% Aggregates results from the parallel computations.
    tile_shift_arr = zeros(tile_num, tile_num, 3);
    tile_shift_loss = -2 * ones(tile_num, tile_num);
    
    for k = 1:length(results)
        res = results{k}; i = res{1}; j = res{2}; shift = res{3}; loss = res{4};
        shift_um = double(shift) .* voxel_len; % Convert shift from voxels to physical units
        tile_shift_arr(i, j, :) = shift_um;
        tile_shift_arr(j, i, :) = -shift_um;
        tile_shift_loss(i, j) = loss;
        tile_shift_loss(j, i) = loss;
    end
end

function [tile_pos_update, tile_refer_id] = update_strip_pos_by_MST(tile_pos, tile_shift_arr, tile_shift_loss)
% Updates global tile positions using a Maximum Spanning Tree algorithm.
% This approach is much more robust than the original Python implementation.
    tile_num = size(tile_pos, 1);
    
    % Create a graph where edge weights are the NEGATIVE of the NCC loss.
    % Finding the Minimum Spanning Tree on negative weights is equivalent to
    % finding the Maximum Spanning Tree on the original weights.
    graph_weights = -tile_shift_loss;
    graph_weights(graph_weights > 0 | isinf(graph_weights) | isnan(graph_weights)) = Inf; % Ignore invalid edges
    
    G = graph(graph_weights, 'upper');
    % 'Root', 1 specifies that Tile 1 is the origin of the coordinate system.
    T = minspantree(G, 'Root', 1);

    tile_pos_update = tile_pos;
    tile_refer_id = zeros(tile_num, 1);
    
    % Traverse the tree using Breadth-First Search (BFS) to ensure parent
    % nodes are always processed before their children.
    order = graphtraverse(T, 1, 'Method', 'BFS');
    
    % Skip the root (node 1), as its position is fixed.
    for i = 2:length(order)
        curr_node = order(i);
        pred_node = predecessors(T, curr_node);
        if isempty(pred_node), continue; end
        
        pred_node = pred_node(1); % Should only be one parent in a tree
        tile_refer_id(curr_node) = pred_node;
        
        % Update the current tile's position based on its parent's final
        % position and the relative shift calculated between them.
        shift_um = squeeze(tile_shift_arr(pred_node, curr_node, :))';
        tile_pos_update(curr_node, :) = tile_pos_update(pred_node, :) + shift_um;
    end
end