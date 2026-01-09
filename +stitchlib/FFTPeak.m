classdef FFTPeak
% Methods for peak-finding and shift calculation.
% Note: This class finds local maxima directly and does not use the Fast
% Fourier Transform (FFT), despite the class name.

methods (Static)
    function peak_coords = find_peak(array, num_peaks)
        % Finds the coordinates of the N highest local maxima (peaks) in a 3D array.
        % This implementation uses a highly optimized, built-in MATLAB function.
        %
        % Inputs:
        %   array:      A 3D numerical array.
        %   num_peaks:  The maximum number of peaks to return.
        %
        % Output:
        %   peak_coords: An N x 3 array of the [x, y, z] coordinates of the
        %                top N peaks, sorted from highest to lowest.

        if nargin < 2, num_peaks = 10; end
        
        % Use imregionalmax to find all regional maxima. This is significantly
        % faster than manual iteration as seen in the Python source.
        peak_mask = imregionalmax(array);
        
        % Get the values and coordinates of the identified peaks.
        peak_values = array(peak_mask);
        [peak_y, peak_x, peak_z] = ind2sub(size(array), find(peak_mask));
        
        % Sort the peaks by their intensity value in descending order.
        [~, sort_idx] = sort(peak_values, 'descend');
        
        % Determine how many peaks to return.
        num_found = min(num_peaks, length(sort_idx));
        
        % Pre-allocate the output array.
        peak_coords = -ones(num_peaks, 3, 'int64');
        
        % Reorder the coordinate vectors based on the sorted peak values.
        sorted_x = peak_x(sort_idx);
        sorted_y = peak_y(sort_idx);
        sorted_z = peak_z(sort_idx);
        
        % Populate the output array in [x, y, z] format.
        peak_coords(1:num_found, :) = [sorted_x(1:num_found), sorted_y(1:num_found), sorted_z(1:num_found)];
    end

    function all_shift_array = get_all_possible_shift(shift_array, img_shape, tile_pos, voxel_len, down_multi)
        % Calculates all 8 possible periodic shifts for a set of input shifts.
        % This function was added from the Python source for completeness.
        %
        % Inputs:
        %   shift_array: An N x 3 array of initial shift vectors.
        %   img_shape:   A [height, width, depth] vector of the image dimensions.
        %   tile_pos:    A 2 x 3 array of the [x,y,z] physical positions of the two tiles.
        %   voxel_len:   A [x,y,z] vector of voxel dimensions.
        %   down_multi:  A [x,y,z] vector of the down-sampling multipliers.
        %
        % Output:
        %   all_shift_array: An (N*8) x 3 array of all possible shift vectors.
        
        num = size(shift_array, 1);
        y = img_shape(1);
        x = img_shape(2);
        z = img_shape(3);

        % Generate 8 periodic versions of the shift vectors
        all_shifts = [shift_array - [0, 0, 0];
                      shift_array - [x, 0, 0];
                      shift_array - [0, y, 0];
                      shift_array - [0, 0, z];
                      shift_array - [0, y, z];
                      shift_array - [x, 0, z];
                      shift_array - [x, y, 0];
                      shift_array - [x, y, z]];

        % Add the initial offset based on the tile positions
        offset = round((tile_pos(1, :) - tile_pos(2, :)) .* down_multi ./ voxel_len);
        all_shift_array = int64(all_shifts + offset);
    end
end
end