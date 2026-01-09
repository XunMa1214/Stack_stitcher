classdef MergeSolution
% An object-oriented solution for blending multiple image tiles.
%
% Algorithm Principle:
% This class takes a series of images and their coordinates and places them
% onto a large canvas one by one. Each time a new tile is added, it is

% seamlessly blended with the pixels already on the canvas using a
% distance-based weighted average (linear blending).
%
    properties
        Result      % The main canvas where the blended image is built.
        Mask        % A logical mask tracking the regions already written to.
        Coord       % Stores the coordinates for each tile.
        ToImgdtype  % The target data type for the final output image (e.g., 'uint16').
        Imgs        % A cell array holding the individual image tiles.
    end
    
    methods
        function obj = MergeSolution(imgs_in, big_img_size, to_imgdtype)
            % Constructs the MergeSolution object.
            %
            % Inputs:
            %   imgs_in: A cell array where each cell contains another cell:
            %            { {img1, coords1}, {img2, coords2}, ... }
            %            `coords` is a 2x2 matrix: [[x_start, x_end]; [y_start, y_end]]
            %   big_img_size: The [height, width] of the final output canvas.
            %   to_imgdtype:  The desired output data type string (e.g., 'uint16').

            if nargin < 3, to_imgdtype = 'uint16'; end
            
            n_imgs = length(imgs_in);
            obj.Imgs = cell(1, n_imgs);
            obj.Coord = zeros(n_imgs, 2, 2, 'int64'); % Stores [x_start, x_end; y_start, y_end]
            
            for i = 1:n_imgs
                img_cell = imgs_in{i};
                obj.Imgs{i} = img_cell{1};
                % Store coordinate ranges for x and y
                obj.Coord(i, 1, :) = img_cell{2}(1,:); % X range
                obj.Coord(i, 2, :) = img_cell{2}(2,:); % Y range
            end
            
            % Add 1-pixel padding around the canvas to simplify border processing.
            obj.Result = zeros(big_img_size(1) + 2, big_img_size(2) + 2, 'single');
            obj.Mask = false(big_img_size(1) + 2, big_img_size(2) + 2);
            obj.Coord = obj.Coord + 1; % Offset all coordinates by +1 due to padding.
            obj.ToImgdtype = to_imgdtype;
        end
        
        function result_img = do(obj)
            % Executes the blending operation for all tiles.
            
            % Place the first image directly onto the canvas without blending.
            img0 = single(obj.Imgs{1});
            xr = obj.Coord(1,1,1):obj.Coord(1,1,2);
            yr = obj.Coord(1,2,1):obj.Coord(1,2,2);
            obj.Result(yr, xr) = img0;
            obj.Mask(yr, xr) = true;

            % Iterate through the remaining images and blend them.
            for i = 2:length(obj.Imgs)
                img = single(obj.Imgs{i});
                xr = obj.Coord(i,1,1):obj.Coord(i,1,2);
                yr = obj.Coord(i,2,1):obj.Coord(i,2,2);
                
                % --- Calculate Blending Weights ---
                
                % Get the mask for the current tile's region. `true` where pixels already exist.
                mask_bg = obj.Mask(yr, xr);
                
                % Background weight: distance from the edge of the new tile.
                % `~mask_bg` is true for new pixel areas. `bwdist` finds the distance
                % from these new areas, creating a ramp up from the overlap edge.
                w_bg = bwdist(~mask_bg);
                
                % Foreground weight: distance from the edge of the existing image.
                % `bwdist(mask_bg)` finds the distance from existing pixels, creating
                % a ramp up from the overlap edge in the other direction.
                w_fg = bwdist(mask_bg);
                
                % Normalize weights so they sum to 1 in the overlapping region.
                wsum = w_bg + w_fg;
                wsum(wsum == 0) = 1; % Prevent division by zero in non-overlapping areas.
                
                w_bg_norm = w_bg ./ wsum;
                w_fg_norm = w_fg ./ wsum;
                
                % Perform the weighted average to blend the images.
                obj.Result(yr, xr) = w_bg_norm .* obj.Result(yr, xr) + w_fg_norm .* img;
                
                % Update the mask to include the newly added tile region.
                obj.Mask(yr, xr) = true;
            end
            
            % Remove the padding and cast to the final output data type.
            result_img = cast(round(obj.Result(2:end-1, 2:end-1)), obj.ToImgdtype);
        end
    end
end