classdef ImgProcess
% Basic image processing functions.

methods(Static)
    function img_down = pyr_down_img(img, times)
        % Down-samples a 3D image stack using an image pyramid.
        % This version, added from the Python source, also down-samples
        % along the 3rd dimension (Z-axis).
        %
        % Inputs:
        %   img:    A 3D image stack (H x W x D).
        %   times:  The number of times to apply the down-sampling.
        %
        % Output:
        %   img_down: The down-sampled 3D image.

        if times == 0, img_down = img; return; end

        img_down = img;
        for t = 1:times
            % Down-sample in X and Y dimensions.
            img_down = impyramid(img_down, 'reduce');
            % Down-sample in Z dimension by taking every other slice.
            img_down = img_down(:, :, 1:2:end);
        end
    end

    function img_down = pyr_down_img_2D(img, times)
        % Down-samples a 2D image using an image pyramid.
        %
        % Inputs:
        %   img:    A 2D image.
        %   times:  The number of times to apply the down-sampling.
        %
        % Output:
        %   img_down: The down-sampled 2D image.

        if times == 0, img_down = img; return; end

        img_down = img;
        for t = 1:times
            img_down = impyramid(img_down, 'reduce');
        end
    end
    
    function [img1_adj, img2_adj] = adjust_contrast(img1, img2, max_mean)
        % Adjusts the contrast of two images to make their mean intensities equal.
        %
        % Inputs:
        %   img1, img2: The two images to adjust.
        %   max_mean:   A floor value for the target mean intensity.
        %
        % Outputs:
        %   img1_adj, img2_adj: The adjusted images.

        if nargin < 3, max_mean = 5; end
        
        original_dtype = class(img1);
        img1f = single(img1); 
        img2f = single(img2);
        
        % Handle potential zero-mean images to prevent division by zero.
        m1 = mean(img1f, 'all'); if m1 == 0, m1=1; end
        m2 = mean(img2f, 'all'); if m2 == 0, m2=1; end
        
        % Determine the target mean value.
        target_mean = max([m1, m2, max_mean]);
        
        % Scale images to the target mean.
        img1_adj = (target_mean / m1) * img1f;
        img2_adj = (target_mean / m2) * img2f;
        
        % Clip the pixel values to the valid range of the original data type.
        if strcmp(original_dtype, 'uint8')
            img1_adj = uint8(min(max(img1_adj, 0), 255));
            img2_adj = uint8(min(max(img2_adj, 0), 255));
        elseif strcmp(original_dtype, 'uint16')
            img1_adj = uint16(min(max(img1_adj, 0), 65535));
            img2_adj = uint16(min(max(img2_adj, 0), 65535));
        else
            % If original type was float/double, no clipping/casting is needed
            % unless a specific range is required. For now, return as single.
        end
    end
end
end