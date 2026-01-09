classdef InfoIO
% Functions to read and write image and stitching metadata.

methods (Static)
    
    %======================================================================
    % --- METADATA IMPORT FUNCTIONS ---
    %======================================================================

    function [dim_elem_num, dim_len, voxel_len, tile_num, tile_pos] = get_img_lif_info(lif_file_path)
        % Reads metadata from a Leica .lif file using the Bio-Formats toolbox.
        % NOTE: Requires the Bio-Formats MATLAB toolbox.
        
        r = bfGetReader(lif_file_path);
        series_count = r.getSeriesCount();
        tile_num = series_count; % In many LIF tile scans, each series is one tile.
        
        % Get dimensions from the first tile/series
        dim_elem_num = int64([r.getSizeX(), r.getSizeY(), r.getSizeZ()]);
        
        % Get physical dimensions to calculate voxel length
        ome = r.getMetadataStore();
        voxel_len = [ome.getPixelsPhysicalSizeX(0).value(), ...
                     ome.getPixelsPhysicalSizeY(0).value(), ...
                     ome.getPixelsPhysicalSizeZ(0).value()];
        dim_len = double(dim_elem_num) .* voxel_len;
        
        % Get tile positions
        tile_pos = zeros(tile_num, 3, 'double');
        for i = 0:tile_num-1
            r.setSeries(i);
            tile_pos(i+1, 1) = ome.getPlanePositionX(i, 0).value();
            tile_pos(i+1, 2) = ome.getPlanePositionY(i, 0).value();
            tile_pos(i+1, 3) = ome.getPlanePositionZ(i, 0).value();
        end
        r.close();
    end
    
    function [dim_elem_num, dim_len, voxel_len, tile_num, tile_pos, img_data_type] = get_img_nd2_info(nd2_file_path)
        % Reads comprehensive metadata from a Nikon .nd2 file.
        % NOTE: Requires the Bio-Formats MATLAB toolbox.
        
        r = bfGetReader(nd2_file_path);
        
        % Get image dimensions
        dim_elem_num = int64([r.getSizeX(), r.getSizeY(), r.getSizeZ()]);
        
        % Get data type
        pixelType = r.getMetadataStore().getPixelsType(0).toString();
        switch char(pixelType)
            case 'uint8', img_data_type = 'uint8';
            case 'uint16', img_data_type = 'uint16';
            otherwise, img_data_type = 'double';
        end
        
        % Check if it's a tile scan by looking for multiple series
        if r.getSeriesCount() > 1
             % Logic for multi-series ND2 files (tile scans)
            tile_num = r.getSeriesCount();
            tile_pos = zeros(tile_num, 3, 'double');
            ome = r.getMetadataStore();
             for i = 0:tile_num-1
                % For ND2, position is often stored per-plane
                tile_pos(i+1, 1) = ome.getPlanePositionX(i, 0).value();
                tile_pos(i+1, 2) = ome.getPlanePositionY(i, 0).value();
                tile_pos(i+1, 3) = ome.getPlanePositionZ(i, 0).value();
             end
             voxel_len = [ome.getPixelsPhysicalSizeX(0).value(), ...
                          ome.getPixelsPhysicalSizeY(0).value(), ...
                          ome.getPixelsPhysicalSizeZ(0).value()];
        else
            % Logic for single-series ND2 with points defined in metadata
            tile_num = r.getSeries(0).getPlaneCount(); % Simplified assumption
            % More complex metadata parsing would be needed for stage positions
            % For now, returning simplified data.
            tile_pos = zeros(tile_num, 3, 'double');
            voxel_len = [1,1,1]; % Default if not found
        end

        dim_len = double(dim_elem_num) .* voxel_len;
        r.close();
    end

    function [dim_elem_num, dim_len, voxel_len, tile_num, tile_pos] = get_img_txt_info(img_path, txt_path, ch_num)
        % Reads tile position information from a specific text file format.
        lines = readlines(txt_path);
        
        coords = [];
        for i = 1:length(lines)
            parts = strsplit(lines{i}, ';');
            if length(parts) >= 3
                % Extract coordinate string like "(x, y)"
                coord_str = erase(parts{end}, {'(', ')', ' '});
                coords(end+1, :) = str2double(strsplit(coord_str, ','));
            end
        end
        
        tile_num = size(coords, 1);
        
        % Determine Z dimension from file count
        file_list = stitchlib.FileRename.get_img_name_list(img_path, 'tif');
        z_num = floor(length(file_list) / tile_num / ch_num);
        
        % Get X,Y dimensions from the first image file
        info = imfinfo(fullfile(img_path, file_list{1}));
        dim_elem_num = int64([info.Width, info.Height, z_num]);
        
        % Assume unit voxel size for TXT-based stitching
        voxel_len = [1, 1, 1];
        dim_len = double(dim_elem_num);
        
        % Assemble tile positions (Z position is assumed to be 0)
        tile_pos = [coords, zeros(tile_num, 1)];
    end
    
    %======================================================================
    % --- METADATA EXPORT FUNCTION ---
    %======================================================================
    
    function save_info_to_xml(xml_path, info_struct)
        % Saves all relevant stitching information to a structured XML file.
        % This is a MATLAB implementation of Python's save_img_xml_info.
        %
        % info_struct should be a struct with fields like:
        %   .img_file_type, .ch_num, .img_data_type, .dim_elem_num, 
        %   .voxel_len, .dim_len, .tile_pos, .tile_shift_arr, 
        %   .tile_shift_loss, .tile_refer_id, .first_last_index

        docNode = com.mathworks.xml.XMLUtils.createDocument('Data');
        root = docNode.getDocumentElement;

        % --- Image Info ---
        if isfield(info_struct, 'img_file_type')
            img_node = docNode.createElement('Image');
            img_node.setAttribute('FileType', info_struct.img_file_type);
            img_node.setAttribute('Channels', num2str(info_struct.ch_num));
            img_node.setAttribute('DataType', info_struct.img_data_type);
            root.appendChild(img_node);
        end
        
        % --- Dimensions Info ---
        if isfield(info_struct, 'dim_elem_num')
            dims_node = docNode.createElement('Dimensions');
            dims = {'X', 'Y', 'Z'};
            for i=1:3
                dim_node = docNode.createElement('Dimension');
                dim_node.setAttribute('DimID', dims{i});
                dim_node.setAttribute('VoxelNum', num2str(info_struct.dim_elem_num(i)));
                dim_node.setAttribute('VoxelLen', num2str(info_struct.voxel_len(i)));
                dim_node.setAttribute('DimLen', num2str(info_struct.dim_len(i)));
                dims_node.appendChild(dim_node);
            end
            root.appendChild(dims_node);
        end
        
        % --- Tile Info ---
        if isfield(info_struct, 'tile_pos')
            tiles_node = docNode.createElement('Tiles');
            tile_num = size(info_struct.tile_pos, 1);
            tiles_node.setAttribute('TileNum', num2str(tile_num));
            for i = 1:tile_num
                tile_node = docNode.createElement('Tile');
                tile_node.setAttribute('TileID', num2str(i-1)); % 0-based ID
                tile_node.setAttribute('PosX', num2str(info_struct.tile_pos(i,1)));
                tile_node.setAttribute('PosY', num2str(info_struct.tile_pos(i,2)));
                tile_node.setAttribute('PosZ', num2str(info_struct.tile_pos(i,3)));
                tiles_node.appendChild(tile_node);
            end
            root.appendChild(tiles_node);
        end
        
        % --- Stitching Info ---
        if isfield(info_struct, 'tile_shift_arr') && isfield(info_struct, 'tile_shift_loss')
            stitches_node = docNode.createElement('Stitches');
            tile_num = size(info_struct.tile_shift_loss, 1);
            for i = 1:tile_num
                for j = 1:tile_num
                    if info_struct.tile_shift_loss(i,j) > 0
                        s_node = docNode.createElement('Stitch');
                        s_node.setAttribute('TileID1', num2str(i-1));
                        s_node.setAttribute('TileID2', num2str(j-1));
                        s_node.setAttribute('ShiftX', num2str(info_struct.tile_shift_arr(i,j,1)));
                        s_node.setAttribute('ShiftY', num2str(info_struct.tile_shift_arr(i,j,2)));
                        s_node.setAttribute('ShiftZ', num2str(info_struct.tile_shift_arr(i,j,3)));
                        s_node.setAttribute('Loss', num2str(info_struct.tile_shift_loss(i,j)));
                        if isfield(info_struct, 'tile_refer_id') && info_struct.tile_refer_id(j) == i-1
                             s_node.setAttribute('IfChosen', 'True');
                        else
                             s_node.setAttribute('IfChosen', 'False');
                        end
                        stitches_node.appendChild(s_node);
                    end
                end
            end
            root.appendChild(stitches_node);
        end
        
        % --- Output Info ---
        if isfield(info_struct, 'first_last_index')
            output_node = docNode.createElement('Output');
            output_node.setAttribute('FirstIndex', num2str(info_struct.first_last_index(1)));
            output_node.setAttribute('LastIndex', num2str(info_struct.first_last_index(2)));
            root.appendChild(output_node);
        end

        xmlwrite(xml_path, docNode);
        fprintf('Stitching metadata successfully saved to %s\n', xml_path);
    end
end
end