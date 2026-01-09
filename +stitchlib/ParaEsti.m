classdef ParaEsti
% Parameter estimation functions.

methods (Static)
    function n = pyr_down_time_esti(img_shape, v_thred)
        % Estimates the optimal number of pyramid down-sampling steps
        % required to reduce an image's total pixel count below a threshold.
        %
        % Inputs:
        %   img_shape: A vector containing the dimensions of the image (e.g., [H, W]).
        %   v_thred:   The target pixel count threshold. Processing is done
        %              on images smaller than this size.
        %
        % Output:
        %   n: The estimated number of down-sampling steps.

        if nargin < 2, v_thred = 800*800; end
        
        total_pixels = prod(img_shape);
        dim = length(img_shape);
        
        n = 0;
        % Each pyramid step reduces pixel count by a factor of 2^dim.
        % Keep incrementing n until the reduced size is below the threshold.
        while (total_pixels / ((2^dim)^n)) > v_thred
            n = n + 1;
        end

        % --- Alternative Logarithmic Calculation ---
        % The while loop above can also be expressed directly as:
        %
        % if total_pixels <= v_thred
        %     n_alt = 0;
        % else
        %     n_alt = floor(log(total_pixels / v_thred) / (dim * log(2))) + 1;
        % end
        %
    end
end
end