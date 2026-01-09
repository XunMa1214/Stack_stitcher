% main_z.m - Main script for Vertical (Z-axis) Stitching

clear; clc; close all;

% --- 1. Required Settings ---
img_file_type = 'tif';      % 'tif', 'nd2', 'lif', 'mtif'
file_path = 'D:\A_lab\A0_plan\MX006\test'; % Path containing the layer subfolders
img_save_path = 'D:\A_lab\A0_plan\MX006\save'; % Path to save the final results

ch_num = 1;                 % Number of channels in the images
ch_th = 0;                  % Channel to use for stitching (0-based index)

% --- 2. Optional Settings ---
img_data_type = 'uint8';    % 'uint8' or 'uint16'
overlap_ratio = 0.4;        % Estimated Z-stack overlap ratio (e.g., 0.4 = 40%)
info_IO_path = file_path;   % Path for intermediate files (defaults to file_path)
pro_num = -1;               % Number of parallel cores to use (-1 for auto)
img_save_type = 'tif';      % Output image type: 'tif', 'PNG', 'JPEG'
compress_ratio = 100;       % Compression quality for JPEG (1-100, 100 is best)


% --- 3. Settings for TIF / MTIF file types ---
img_name_format = ''; 
img_name = ''; 
if_rename_file = false;

if strcmpi(img_file_type, 'tif')
    % Sprintf format for file naming.
    % Example: sprintf(img_name_format, 'img', 0, 0, 'tif') -> 'img_z0000_ch00.tif'
    img_name_format = '%s_z%.4d_ch%.2d.%s';
    img_name = 'img';
    if_rename_file = true; % Set to true if files need renaming to the format above
elseif strcmpi(img_file_type, 'mtif')
    img_name_format = '%s_ch%.2d.%s';
    img_name = 'Region';
    if_rename_file = true;
end

% --- 4. Start Vertical Stitching ---
fprintf('Starting vertical stitching process...\n');

% Call the main function from the stitchlib library
stitchlib.VertStitchMerged(file_path, img_save_path, img_name_format, info_IO_path, ...
                           img_name, ch_num, ch_th, img_file_type, img_data_type, ...
                           overlap_ratio, if_rename_file, pro_num, img_save_type, compress_ratio);

fprintf('Vertical stitching process has completed.\n');

