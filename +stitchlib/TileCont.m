classdef TileCont
% Functions to determine the adjacency relationships between image tiles.

methods(Static)
    function tile_contact = judge_tile_cont(dim_len, tile_pos, tile_cont_thre)
        % Determines which pairs of tiles are adjacent based on their positions.
        %
        % Inputs:
        %   dim_len:         A [width, height, depth] vector of tile dimensions
        %                    in physical units.
        %   tile_pos:        An N x 3 matrix of the [x,y,z] physical starting
        %                    positions for each of the N tiles.
        %   tile_cont_thre:  A threshold controlling how much overlap is required
        %                    to be considered "in contact". Default is 0.8.
        %
        % Output:
        %   tile_contact:    An N x N logical matrix where tile_contact(i, j)
        %                    is true if tile i and tile j are adjacent.

        if nargin < 3, tile_cont_thre = 0.8; end
        
        tile_num = size(tile_pos, 1);
        tile_contact = false(tile_num, tile_num);
        
        % Define the distance thresholds for contact in X and Y directions.
        % For X-contact, the Y and Z distances must be small.
        % For Y-contact, the X and Z distances must be small.
        if_x = dim_len .* [1, 1 - tile_cont_thre, 1 - tile_cont_thre];
        if_y = dim_len .* [1 - tile_cont_thre, 1, 1 - tile_cont_thre];
        
        % Iterate through each unique pair of tiles.
        for i = 1:tile_num
            for j = i+1:tile_num
                % Calculate the absolute distance between the tile centers.
                dist = abs(tile_pos(i, :) - tile_pos(j, :));
                
                % If the distance meets the criteria for being primarily overlapped
                % in either the X or Y direction, mark them as in contact.
                if all(dist < if_x) || all(dist < if_y)
                    tile_contact(i, j) = true;
                    tile_contact(j, i) = true; % The relationship is symmetric.
                end
            end
        end
    end
end
end