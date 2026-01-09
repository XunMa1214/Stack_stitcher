classdef ImgOvl
% Extracts pixel data from the overlapping regions of two 3D image stacks.

methods (Static)
    function [ovl1_list, ovl2_list] = get_ovl_img(img1, img2, border, if_sparce)
        % Extracts overlapping regions based on border coordinates.
        %
        % Inputs:
        %   img1:       The first 3D image stack.
        %   img2:       The second 3D image stack.
        %   border:     A 2x6 matrix defining the [xmin,xmax,ymin,ymax,zmin,zmax]
        %               indices of the overlap for each image, from ImgBorder.
        %   if_sparce:  A boolean flag. If true, returns Maximum Intensity
        %               Projections. If false, returns the 6 outer faces
        %               of the overlapping volume.
        %
        % Outputs:
        %   ovl1_list:  A cell array of 2D image planes from img1's overlap.
        %   ovl2_list:  A cell array of 2D image planes from img2's overlap.
        
        ovl1_list = {}; 
        ovl2_list = {};

        % --- 1. Input Validation ---
        % Check if the border is valid before proceeding.
        if isempty(border) || any(border(1, 1:2:end) >= border(1, 2:2:end)) || any(border(2, 1:2:end) >= border(2, 2:2:end))
            return;
        end

        b1 = border(1,:); % Overlap border for img1: [x1,x2,y1,y2,z1,z2]
        b2 = border(2,:); % Overlap border for img2
        
        if if_sparce
            % --- 2a. Sparse Mode: Maximum Intensity Projections ---
            
            % Extract the 3D overlapping sub-volumes from each image.
            img1_ovl = img1(b1(3):b1(4), b1(1):b1(2), b1(5):b1(6));
            img2_ovl = img2(b2(3):b2(4), b2(1):b2(2), b2(5):b2(6));
            
            % Calculate the MIP along each of the three axes (dim 1, 2, 3).
            ovl1_list{1} = squeeze(max(img1_ovl, [], 1)); % YZ projection
            ovl1_list{2} = squeeze(max(img1_ovl, [], 2)); % XZ projection
            ovl1_list{3} = squeeze(max(img1_ovl, [], 3)); % XY projection
            
            ovl2_list{1} = squeeze(max(img2_ovl, [], 1));
            ovl2_list{2} = squeeze(max(img2_ovl, [], 2));
            ovl2_list{3} = squeeze(max(img2_ovl, [], 3));
        else
            % --- 2b. Dense Mode: 6 Outer Faces of the Overlap Volume ---
            try
                % Extract the 2D faces from img1.
                ovl1_list{1} = squeeze(img1(b1(3):b1(4), b1(1),     b1(5):b1(6))); % Min X face
                ovl1_list{2} = squeeze(img1(b1(3):b1(4), b1(2),     b1(5):b1(6))); % Max X face
                ovl1_list{3} = squeeze(img1(b1(3),     b1(1):b1(2), b1(5):b1(6))); % Min Y face
                ovl1_list{4} = squeeze(img1(b1(4),     b1(1):b1(2), b1(5):b1(6))); % Max Y face
                ovl1_list{5} = squeeze(img1(b1(3):b1(4), b1(1):b1(2), b1(5)    )); % Min Z face
                ovl1_list{6} = squeeze(img1(b1(3):b1(4), b1(1):b1(2), b1(6)    )); % Max Z face
                
                % Extract the corresponding 2D faces from img2.
                ovl2_list{1} = squeeze(img2(b2(3):b2(4), b2(1),     b2(5):b2(6)));
                ovl2_list{2} = squeeze(img2(b2(3):b2(4), b2(2),     b2(5):b2(6)));
                ovl2_list{3} = squeeze(img2(b2(3),     b2(1):b2(2), b2(5):b2(6)));
                ovl2_list{4} = squeeze(img2(b2(4),     b2(1):b2(2), b2(5):b2(6)));
                ovl2_list{5} = squeeze(img2(b2(3):b2(4), b2(1):b2(2), b2(5)    ));
                ovl2_list{6} = squeeze(img2(b2(3):b2(4), b2(1):b2(2), b2(6)    ));
            catch ME
                % If any indexing fails, return empty lists.
                fprintf('Warning: Indexing error in get_ovl_img. Returning empty. Error: %s\n', ME.message);
                ovl1_list = {}; 
                ovl2_list = {};
            end
        end
    end
end
end