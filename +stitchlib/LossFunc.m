classdef LossFunc
% Defines the similarity loss functions used for image alignment.

methods (Static)
    function loss = loss_func_z_stitch(ovl1, ovl2)
        % Calculates the Normalized Cross-Correlation (NCC) between two 2D image regions.
        % NCC is a robust measure of similarity, ranging from -1 to +1.
        %
        % Inputs:
        %   ovl1, ovl2: The two overlapping 2D image regions.
        %
        % Output:
        %   loss: The calculated NCC score. Returns -1 if inputs are invalid.

        if isempty(ovl1) || isempty(ovl2) || numel(ovl1) ~= numel(ovl2)
            loss = -1; % Invalid input
            return;
        end
        
        ovl1 = single(ovl1); 
        ovl2 = single(ovl2);
        
        % Subtract the mean to make the correlation illumination-invariant.
        ovl1 = ovl1 - mean(ovl1, 'all');
        ovl2 = ovl2 - mean(ovl2, 'all');
        
        % Calculate the numerator of the NCC formula.
        numerator = mean(ovl1 .* ovl2, 'all');
        
        % Calculate the denominator. Using std(..., 1, 'all') normalizes by N,
        % which is consistent with the numpy.std() default behavior.
        denominator = std(ovl1, 1, 'all') * std(ovl2, 1, 'all');
        
        if denominator < 1e-6 % Avoid division by nearly zero.
            loss = 0; % If there is no variance, there is no correlation.
        else
            loss = numerator / denominator;
        end
    end
    
    function loss = loss_func_for_list(ovl1_list, ovl2_list)
        % Calculates a weighted average of the NCC score for lists of
        % corresponding image planes (e.g., the 6 faces of an overlap volume).
        % This function was added from the Python source for completeness.
        %
        % Inputs:
        %   ovl1_list: Cell array of 2D image planes from the first stack.
        %   ovl2_list: Cell array of 2D image planes from the second stack.
        %
        % Output:
        %   loss: The final weighted-average NCC score.

        ovl_num = length(ovl1_list);
        if ovl_num == 0 || ovl_num ~= length(ovl2_list)
            loss = -1; % Return -1 for invalid input.
            return;
        end

        weights = zeros(ovl_num, 1, 'single');
        for i = 1:ovl_num
            weights(i) = numel(ovl1_list{i}); % Weight by the size (pixel count) of the plane.
        end
        
        % Normalize weights to sum to 1.
        total_weight = sum(weights);
        if total_weight == 0, loss = -1; return; end
        weights = weights / total_weight;
        
        total_loss = 0;
        for i = 1:ovl_num
            % Calculate the NCC for the current pair of planes.
            ncc_single = stitchlib.LossFunc.loss_func_z_stitch(ovl1_list{i}, ovl2_list{i});
            
            % Add the weighted score to the total.
            if ncc_single > -1 % Only include valid scores
                total_loss = total_loss + weights(i) * ncc_single;
            end
        end
        loss = total_loss;
    end
end
end