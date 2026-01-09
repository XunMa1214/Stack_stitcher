classdef AxisRange
% Functions to calculate the spatial range of the stitched image.

methods (Static)
    function [axis_range, voxel_num] = calc_axis_range(tile_pos, dim_elem_num, voxel_len)
        % Calculates the boundaries and voxel count of the final canvas.
        min_pos = min(tile_pos, [], 1);
        max_pos = max(tile_pos, [], 1) + double(dim_elem_num) .* voxel_len;
        axis_range = [min_pos', max_pos'];
        voxel_num = int64(round((axis_range(:, 2) - axis_range(:, 1))' ./ voxel_len));
    end

    function first_last_index = find_first_last_index(tile_pos, dim_elem_num, axis_range, voxel_len, voxel_num)
        % Finds the first and last Z-slices that contain data from all tiles.
        first_last_index = [voxel_num(3), 1];
        tile_num = size(tile_pos, 1);
        
        for i = 1:voxel_num(3) % Z-slices (1-based)
            this_z = axis_range(3, 1) + voxel_len(3) * (i-1);
            num_one_layer = 0;
            for j = 1:tile_num
                tile_z_start = tile_pos(j, 3);
                tile_z_end = tile_pos(j, 3) + double(dim_elem_num(3)) * voxel_len(3);
                
                if this_z >= tile_z_start && this_z < tile_z_end
                    num_one_layer = num_one_layer + 1;
                end
            end
            
            % The logic (from the Python source) is to find Z-layers where all tiles exist.
            if num_one_layer == tile_num
                if i < first_last_index(1), first_last_index(1) = i; end
                if i >= first_last_index(2), first_last_index(2) = i; end
            end
        end
    end
end
end