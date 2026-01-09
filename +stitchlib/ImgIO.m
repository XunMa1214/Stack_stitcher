classdef ImgIO
% Image Input/Output (I/O) and final image export functions.

methods (Static)

    %======================================================================
    % --- IMAGE IMPORT HELPERS ---
    %======================================================================
    
    function one_img = import_img_2D(img_name_format, img_path, img_name, z_th, ch_th, img_type, ~)
        % Imports a single 2D TIFF image from a file path.
        % Assumes z_th and ch_th are 0-based for file naming.
        one_img_name = fullfile(img_path, sprintf(img_name_format, img_name, z_th, ch_th, img_type));
        one_img = imread(one_img_name);
    end

    function img_2d = import_img_2D_tile(img_name_format, img_path, img_name, tile_idx, z_th, ch_th, ~, ~, ~)
        % Imports a single 2D TIFF image corresponding to a specific tile.
        % Assumes tile_idx, z_th, ch_th are 0-based.
        one_img_name = fullfile(img_path, sprintf(img_name_format, img_name, tile_idx, z_th, ch_th, 'tif'));
        img_2d = imread(one_img_name);
    end
    
    function voxel_array = import_img_one_tile_stack(img_name_format, img_path, img_name, tile_idx, ch_th, dim_elem_num, img_type, img_data_type)
        % Imports a full 3D stack for a single tile from a sequence of 2D TIFF files.
        voxel_array = zeros(dim_elem_num(2), dim_elem_num(1), dim_elem_num(3), img_data_type); % H x W x D
        for z_idx = 0:dim_elem_num(3)-1
            one_img_name = fullfile(img_path, sprintf(img_name_format, img_name, tile_idx, z_idx, ch_th, img_type));
            voxel_array(:,:,z_idx+1) = imread(one_img_name);
        end
    end
    
    % --- Placeholder functions for ND2/LIF formats ---
    % NOTE: Implementing these requires the Bio-Formats for MATLAB toolbox.
    % https://www.openmicroscopy.org/bio-formats/downloads/
    
    function img_2D = get_img_2D_from_nd2(bf_reader, series_idx, z_idx, ch_idx)
        % Placeholder to get a 2D slice from an open ND2 reader.
        % bf_reader: The reader object from bfGetReader().
        % series_idx, z_idx, ch_idx are all 0-based.
        plane_idx = bf_reader.getIndex(z_idx, ch_idx, 0) + 1; % Z, C, T (1-based for bfGetPlane)
        img_2D = bfGetPlane(bf_reader, plane_idx);
    end

    %======================================================================
    % --- IMAGE EXPORT FUNCTIONS ---
    %======================================================================

    function export_img_hori_stit(img_path, img_save_path, img_name_format, img_name, ch_num, img_type, img_data_type, dim_elem_num, dim_len, voxel_len, tile_pos, axis_range, first_last_index, ~, if_blend)
        % Exports horizontally stitched images, slice by slice.
        % This version is updated to use the superior `stitchlib.Blend` function.
        tile_num = size(tile_pos, 1);
        voxel_num = int64(round((axis_range(:, 2) - axis_range(:, 1))' ./ voxel_len));

        img_num = 0; % 0-based counter for saved file names
        for j = first_last_index(1):first_last_index(2) % Loop through Z-slices (1-based)
            for ch_th = 0:ch_num-1 % Loop through channels (0-based)
                
                % Get physical Z position of the current slice
                this_z_um = axis_range(3,1) + voxel_len(3) * (j-1);
                
                % Prepare arrays to hold data for the current slice
                tiles_for_slice = cell(tile_num, 1);
                positions_for_slice = zeros(tile_num, 2, 'int64');
                tile_count = 0;
                
                % Collect all tiles that are part of the current Z-slice
                for k = 1:tile_num
                    % Check if the current Z-slice is within the physical range of tile k
                    if this_z_um < tile_pos(k, 3) || this_z_um >= tile_pos(k, 3) + dim_len(3), continue; end
                    
                    % Calculate the relative z-index within tile k's stack
                    z_th = round((this_z_um - tile_pos(k, 3)) / voxel_len(3));
                    if z_th < 0 || z_th >= dim_elem_num(3), continue; end
                    
                    % Load the 2D image for the current tile, z-slice, and channel
                    img_2d = stitchlib.ImgIO.import_img_2D_tile(img_name_format, img_path, img_name, k-1, z_th, ch_th);
                    
                    % Calculate the tile's top-left position on the final canvas
                    x_canvas_pos = int64(round((tile_pos(k, 1) - axis_range(1, 1)) / voxel_len(1))) + 1;
                    y_canvas_pos = int64(round((tile_pos(k, 2) - axis_range(2, 1)) / voxel_len(2))) + 1;
                    
                    tile_count = tile_count + 1;
                    tiles_for_slice{tile_count} = img_2d;
                    positions_for_slice(tile_count,:) = [x_canvas_pos, y_canvas_pos];
                end
                
                if tile_count == 0, continue; end % Skip if no tiles were found for this slice
                
                % Trim empty cells
                tiles_for_slice = tiles_for_slice(1:tile_count);
                positions_for_slice = positions_for_slice(1:tile_count, :);
                
                % Generate the final image for the slice
                if if_blend
                    % Re-stack tiles into a 3D array for the blend function
                    img_array_for_blend = cat(3, tiles_for_slice{:});
                    final_slice = stitchlib.Blend(img_array_for_blend, positions_for_slice, voxel_num);
                else
                    % Simple pasting ("last on top") if not blending
                    final_slice = zeros(voxel_num(2), voxel_num(1), img_data_type);
                    for t = 1:tile_count
                        img_to_place = tiles_for_slice{t};
                        [h, w] = size(img_to_place);
                        x_p = positions_for_slice(t, 1);
                        y_p = positions_for_slice(t, 2);
                        final_slice(y_p:(y_p+h-1), x_p:(x_p+w-1)) = img_to_place;
                    end
                end
                
                % Save the final stitched slice
                save_name = sprintf('%s_z%.4d_ch%.2d.tif', img_name, img_num, ch_th);
                imwrite(final_slice, fullfile(img_save_path, save_name));
            end
            img_num = img_num + 1;
        end
    end
    
    function export_img_vert_stit(file_path, file_list, img_save_path, axis_range_array, first_last_index, img_name_format, img_name, ch_num, img_file_type, img_data_type, ~, ~)
        % Exports vertically stitched images by placing each full layer onto a final canvas.
        layer_num = size(axis_range_array, 1);
        
        % Calculate the size of the final canvas needed to hold all layers
        xy_axis_min = squeeze(min(axis_range_array(:, :, 1), [], 1));
        xy_axis_max = squeeze(max(axis_range_array(:, :, 2), [], 1));
        canvas_size = xy_axis_max - xy_axis_min;

        img_num = 0; % 0-based counter for output file names
        for i = 1:layer_num
            img_path = fullfile(file_path, file_list{i});
            
            if first_last_index(i,1) > first_last_index(i,2), continue; end % Skip empty layers
            
            % Calculate this layer's top-left offset on the final canvas
            x_offset = axis_range_array(i,1,1) - xy_axis_min(1) + 1;
            y_offset = axis_range_array(i,2,1) - xy_axis_min(2) + 1;
            
            % Loop through the relevant z-slices for this layer
            for j = first_last_index(i,1):first_last_index(i,2)
                for c = 0:ch_num-1
                    final_slice = zeros(canvas_size(2), canvas_size(1), img_data_type);
                    
                    % Convert MATLAB's 1-based loop index 'j' to 0-based for file loading
                    z_index_for_file = j - 1;
                    
                    img_2d = stitchlib.ImgIO.import_img_2D(img_name_format, img_path, img_name, z_index_for_file, c, img_file_type, img_data_type);
                    
                    [h, w] = size(img_2d);
                    
                    % Place the loaded image onto the canvas at the correct offset
                    final_slice(y_offset:(y_offset+h-1), x_offset:(x_offset+w-1)) = img_2d;
                    
                    % Save the final stitched slice
                    save_name = sprintf('%s_z%.4d_ch%.2d.tif', img_name, img_num, c);
                    imwrite(final_slice, fullfile(img_save_path, save_name));
                end
                img_num = img_num + 1;
            end
        end
        fprintf('Successfully exported all vertically stitched images to %s\n', img_save_path);
    end
end
end