classdef FileRename
% A collection of utility functions for batch-renaming image files.

methods(Static)
    function file_list = pop_other_type_file(file_list_in, file_type)
        % Filters a cell array of filenames, keeping only those that contain
        % the specified file extension.
        % NOTE: The original version had a bug using '~contains', which kept
        % the wrong files. This version is corrected.
        if isempty(file_list_in) || (iscell(file_list_in) && isempty(file_list_in{1}))
            file_list = {}; 
            return;
        end
        % Keep elements that DO contain the file type string.
        keep_mask = contains(file_list_in, ['.', file_type]);
        file_list = file_list_in(keep_mask);
    end

    function file_list = get_img_name_list(img_path, file_type)
        % Gets a sorted list of files of a specific type from a directory.
        % Sorting is critical for ensuring consistent renaming order.
        files = dir(fullfile(img_path, ['*.', file_type]));
        file_list = {files.name};
        file_list = sort(file_list);
    end
    
    function rename_file(img_name_format, img_path, img_name, z_num, ch_num, img_type)
        % Renames files for horizontal stitching (tiled acquisitions).
        % Assumes files are sorted by tile, then z, then channel.
        file_list = stitchlib.FileRename.get_img_name_list(img_path, img_type);
        file_num = length(file_list);
        tile_num = floor(file_num / z_num / ch_num);
        
        file_idx = 1;
        for i = 0:tile_num-1  % Tile index
            for z = 0:z_num-1      % Z-slice index
                for c = 0:ch_num-1 % Channel index
                    if file_idx > file_num, break; end
                    
                    old_name = fullfile(img_path, file_list{file_idx});
                    new_name = fullfile(img_path, sprintf(img_name_format, img_name, i, z, c, img_type));
                    
                    if ~strcmp(old_name, new_name)
                        movefile(old_name, new_name);
                    end
                    file_idx = file_idx + 1;
                end
            end
        end
    end

    function rename_file_mtif(img_name_format, img_path, img_name, ch_num)
        % Renames files for multi-page TIF format.
        file_list = stitchlib.FileRename.get_img_name_list(img_path, 'tif');
        for i = 0:ch_num-1 % Channel index
            if i+1 > length(file_list), break; end
            
            old_name = fullfile(img_path, file_list{i+1});
            new_name = fullfile(img_path, sprintf(img_name_format, img_name, i, 'tif'));
            
            if ~strcmp(old_name, new_name)
                movefile(old_name, new_name);
            end
        end
    end

    function rename_file_Z_stit(img_name_format, img_path, img_name, z_num, ch_num, img_type)
        % Renames files for vertical stitching.
        % Assumes files are sorted by z, then channel.
        file_list = stitchlib.FileRename.get_img_name_list(img_path, img_type);
        file_idx = 1;
        for z = 0:z_num-1      % Z-slice index
            for c = 0:ch_num-1 % Channel index
                if file_idx > length(file_list), break; end
                
                old_name = fullfile(img_path, file_list{file_idx});
                new_name = fullfile(img_path, sprintf(img_name_format, img_name, z, c, img_type));

                 if ~strcmp(old_name, new_name)
                    movefile(old_name, new_name);
                end
                file_idx = file_idx + 1;
            end
        end
    end
end
end