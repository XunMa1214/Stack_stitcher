% main_xy.m - Main script for Horizontal (XY) Stitching

clear; clc; close all;

% --- 1. Required Settings ---
img_file_type = 'tif';      % 'nd2', 'lif', 'tif'
img_path = ''; % Path to the folder containing image tiles
img_save_path = ''; % Path to save the final results
ch_num = 1;                 % Number of channels
ch_th = 0;                  % Channel to use for stitching (0-based index)
img_data_type = 'uint16';   % 'uint8' or 'uint16'

% --- 2. Optional Settings ---
[info_IO_path, ~, ~] = fileparts(img_path); % Path for metadata files (defaults to parent dir)
move_ratio = [0.05, 0.05, 0]; % Overlap search range ratio for [X, Y, Z]
if_sparce = false;            % True if data is sparse (affects overlap calculation)
if_high_noise = false;        % True to use a larger median filter kernel
pro_num = -1;                 % Number of parallel cores to use (-1 for auto)
if_blend = true;              % True to blend overlapping tile edges

% --- 3. Settings for TIF files ---
% These are required if img_file_type is 'tif'
img_name_format = '%s_t%.4d_z%.4d_ch%.2d.%s'; % Sprintf format: (name, tile, z, ch, ext)
img_name = 'Region';
info_file_path = 'D:\path\to\your\metadata\position.txt'; % Path to .txt or .xml metadata
if_rename_file = true;       % Set to true if files need to be renamed to the format

% --- 4. Start Horizontal Stitching ---
fprintf('Starting horizontal stitching process...\n');

% Call the main function from the stitchlib library
% Note: The 'if_pos_info' argument from Python is handled by providing a valid info_file_path.
stitchlib.HoriStitch(info_IO_path, info_file_path, img_file_type, img_path, img_save_path, ...
                     img_name_format, img_name, ch_num, ch_th, img_data_type, [], ...
                     move_ratio, if_sparce, if_high_noise, if_rename_file, if_blend, pro_num);
                     
fprintf('Horizontal stitching process has completed.\n');