function whole_img = Blend(img_array, tile_pos, voxel_num)
% Blends multiple image tiles seamlessly using a weighted average based on
% a distance transform. This method provides a smooth transition in 
% overlapping regions.
%
% Inputs:
%   img_array:  A Y x X x TileNum array of image tiles.
%   tile_pos:   A TileNum x 2 array containing the top-left [x, y] 
%               coordinates (1-based) for each tile.
%   voxel_num:  A [width, height] vector defining the final canvas size.

    % --- 1. Initialization ---

    % Sigma for the Gaussian weight falloff, scaled to image size.
    sigma = round(0.05 * mean(voxel_num));
    if sigma < 1, sigma = 1; end
    
    img_dtype = class(img_array);
    img = single(img_array);
    tile_num = size(img, 3);
    tile_len = [size(img, 2), size(img, 1)]; % [width, height]

    % Initialize the final canvas.
    whole_img = zeros(voxel_num(2), voxel_num(1), 'single'); % Y, X

    % --- 2. Place First Tile ---
    
    % The first tile is placed directly on the canvas without blending.
    x_range_1 = tile_pos(1,1):(tile_pos(1,1) + tile_len(1) - 1);
    y_range_1 = tile_pos(1,2):(tile_pos(1,2) + tile_len(2) - 1);
    whole_img(y_range_1, x_range_1) = img(:,:,1);
    
    % --- 3. Blend Subsequent Tiles ---
    
    for i = 2:tile_num
        % Get the new tile to be blended.
        new_tile = img(:,:,i);
        
        % --- Calculate Foreground Weight (for the new tile) ---
        % The weight of a pixel is based on its distance from the nearest
        % edge (or zero-intensity pixel).
        % bwdist calculates the distance to the nearest non-zero pixel from a
        % logical mask. We invert the logic to get distance from the edge.
        weight_fg = bwdist(new_tile < 1e-6); 
        
        % Apply a Gaussian function to create a smooth falloff.
        % Pixels far from the edge will have a weight near 1.
        % Pixels near the edge will have a weight near 0.
        weight_fg = 1 - exp(-(weight_fg / sigma).^2);

        % --- Calculate Background Weight (for the existing canvas) ---
        % Get the corresponding region from the main canvas.
        x_range_i = tile_pos(i,1):(tile_pos(i,1) + tile_len(1) - 1);
        y_range_i = tile_pos(i,2):(tile_pos(i,2) + tile_len(2) - 1);
        background_region = whole_img(y_range_i, x_range_i);
        
        % Calculate weight for the background region using the same method.
        weight_bg = bwdist(background_region < 1e-6);
        weight_bg = 1 - exp(-(weight_bg / sigma).^2);
        
        % --- Normalize Weights and Blend ---
        % In the overlapping region, the sum of weights must be 1 to avoid
        % changing the intensity.
        weight_sum = weight_fg + weight_bg;
        weight_sum(weight_sum == 0) = 1; % Avoid division by zero in non-overlapping areas.
        
        normalized_fg_weight = weight_fg ./ weight_sum;
        normalized_bg_weight = weight_bg ./ weight_sum;
        
        % Perform the weighted average.
        blended_region = (normalized_bg_weight .* background_region) + (normalized_fg_weight .* new_tile);
        
        % Place the blended region back onto the main canvas.
        whole_img(y_range_i, x_range_i) = blended_region;
    end
    
    % --- 4. Finalize ---
    
    % Convert the final image back to its original data type.
    whole_img = cast(round(whole_img), img_dtype);
end