function PosGene(txt_path, x_num, y_num, x_v, y_v, ovl_r)
% PosGene: Generates an initial coordinate file for grid-aligned tiles.
% This is useful when metadata is not available from the microscope.
%
% Inputs:
%   txt_path:  The full path of the .txt file to be saved.
%   x_num:     The number of tiles in the X direction.
%   y_num:     The number of tiles in the Y direction.
%   x_v:       The width of a single tile in pixels.
%   y_v:       The height of a single tile in pixels.
%   ovl_r:     The overlap ratio between tiles (e.g., 0.1 for 10% overlap).

    fid = fopen(txt_path, 'w');
    if fid == -1
        error('Unable to open file for writing: %s', txt_path);
    end
    
    fprintf('Generating coordinate file at: %s\n', txt_path);
    
    for y = 0:y_num-1
        for x = 0:x_num-1
            % Calculate the top-left coordinate for each tile.
            x_pos = x * x_v * (1 - ovl_r);
            y_pos = y * y_v * (1 - ovl_r);
            
            % Write to file in a format consistent with the reader function.
            % Format: "YY X XX;;(x_coord, y_coord)"
            fprintf(fid, '%.2d X %.2d;;(%d, %d)\n', y, x, round(x_pos), round(y_pos));
        end
    end
    
    fclose(fid);
    fprintf('Coordinate file generated successfully.\n');
end