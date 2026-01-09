classdef ImgBorder
% Functions to calculate the boundaries of overlapping image regions.

methods (Static)
    function voxel_border = get_2img_border(dim_elem_num, dim_len, voxel_len, tile_pos)
        % Calculates the coordinates of the overlapping region between two tiles.
        %
        % Inputs:
        %   dim_elem_num: A [width, height, depth] vector of tile dimensions in voxels.
        %   dim_len:      A [width, height, depth] vector of tile dimensions in physical units.
        %   voxel_len:    A [width, height, depth] vector of voxel dimensions in physical units.
        %   tile_pos:     A 2x3 matrix of the [x,y,z] physical starting positions of the two tiles.
        %
        % Output:
        %   voxel_border: A 2x6 matrix where each row contains the voxel indices
        %                 [x_min, x_max, y_min, y_max, z_min, z_max] for the
        %                 overlapping region relative to each tile's own coordinate system.
        %                 Returns an empty array if there is no valid overlap.

        % Find the physical boundaries of the overlapping rectangular prism.
        x_min = max(tile_pos(:,1));
        x_max = min(tile_pos(:,1) + dim_len(1));
        y_min = max(tile_pos(:,2));
        y_max = min(tile_pos(:,2) + dim_len(2));
        z_min = max(tile_pos(:,3));
        z_max = min(tile_pos(:,3) + dim_len(3));

        % Convert physical coordinates to voxel indices for Tile 1 (1-based).
        v1 = [round((x_min - tile_pos(1,1))/voxel_len(1))+1, round((x_max - tile_pos(1,1))/voxel_len(1)), ...
              round((y_min - tile_pos(1,2))/voxel_len(2))+1, round((y_max - tile_pos(1,2))/voxel_len(2)), ...
              round((z_min - tile_pos(1,3))/voxel_len(3))+1, round((z_max - tile_pos(1,3))/voxel_len(3))];

        % Convert physical coordinates to voxel indices for Tile 2 (1-based).
        v2 = [round((x_min - tile_pos(2,1))/voxel_len(1))+1, round((x_max - tile_pos(2,1))/voxel_len(1)), ...
              round((y_min - tile_pos(2,2))/voxel_len(2))+1, round((y_max - tile_pos(2,2))/voxel_len(2)), ...
              round((z_min - tile_pos(2,3))/voxel_len(3))+1, round((z_max - tile_pos(2,3))/voxel_len(3))];
        
        % Check if the overlap is valid (i.e., min index is less than max index).
        if any(v1(1:2:end) >= v1(2:2:end)) || any(v2(1:2:end) >= v2(2:2:end))
            voxel_border = []; 
            return;
        end
        
        % Clamp indices to be within the valid voxel dimensions.
        v1 = max(v1, 1); 
        v2 = max(v2, 1);
        v1([2,4,6]) = min(v1([2,4,6]), dim_elem_num);
        v2([2,4,6]) = min(v2([2,4,6]), dim_elem_num);

        voxel_border = int64(round([v1; v2]));
    end

    function border_pyr_down = get_border_pyr_down(border, down_multi)
        % Calculates border coordinates for a down-sampled image pyramid.
        % This function was added from the Python source for completeness.
        %
        % Inputs:
        %   border:       The 2x6 voxel_border matrix from get_2img_border.
        %   down_multi:   A 1x3 vector of the down-sampling multipliers for [x, y, z].
        %
        % Output:
        %   border_pyr_down: The corresponding 2x6 border matrix for the
        %                    down-sampled image.

        if isempty(border)
            border_pyr_down = [];
            return;
        end
        
        border_pyr_down = zeros(2, 6, 'int64');
        border = double(border); % Use double for calculations
        
        % Scale coordinates by the down-sampling factor.
        border_pyr_down(:, 1:2) = int64(round(border(:, 1:2) * down_multi(1)));
        border_pyr_down(:, 2:4) = int64(round(border(:, 2:4) * down_multi(2)));
        border_pyr_down(:, 4:6) = int64(round(border(:, 4:6) * down_multi(3)));
        
        % Ensure the size of the overlapping region is consistent for both tiles
        % after down-sampling and rounding.
        for i = 1:3
            idx1 = 2 * i - 1;
            idx2 = 2 * i;
            size1 = border_pyr_down(1, idx2) - border_pyr_down(1, idx1);
            border_pyr_down(2, idx2) = border_pyr_down(2, idx1) + size1;
        end
    end
end
end