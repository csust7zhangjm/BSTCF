%   This function runs the ASRCF tracker on the video specified in "seq".
%   This function borrowed from SRDCF paper. 
%   details of some parameters are not presented in the paper, you can
%   refer to SRDCF/CCOT paper for more details.

function [] = run_BSTCF_VOT(seq, video_path, videos, vid, Ir)

global enableGPU;
enableGPU = true;
setup_path();
%   HOG feature parameters
hog_params.nDim   = 31;
cn_params.nDim    =10;
cn_params.tablename = 'CNnorm';
cn_params.useForGray = false;
params.video_path = video_path;

% %%%…Ó∂»Ãÿ’˜
% cnn_params.nn_name = 'imagenet-vgg-m-2048.mat'; % Name of the network
% cnn_params.output_layer = [10];           % Which layers to use
% cnn_params.downsample_factor = [1];           % How much to downsample each output layer
% cnn_params.input_size_mode = 'adaptive';        % How to choose the sample size
% cnn_params.input_size_scale = 1;  
% % %%%

%   Global feature parameters 
params.t_features = {
%     struct('getFeature',@get_colorspace, 'fparams',grayscale_params),...  % Grayscale is not used as default
    struct('getFeature',@get_fhog,'fparams',hog_params),...
%    struct('getFeature',@get_vggmfeatures, 'fparams',cnn_params),...%%%CNN
    struct('getFeature',@get_table_feature, 'fparams',cn_params),...
%    struct('getFeature',@prevggmfeature,'fparams',prevggm_params),...
    };

params.t_global.cell_size = 4;                  % Feature cell size
params.t_global.cell_selection_thresh = 0.75^2; % Threshold for reducing the cell size in low-resolution cases

%   Search region + extended background parameters
params.search_area_shape = 'square';    % the shape of the training/detection window: 'proportional', 'square' or 'fix_padding'
params.search_area_scale = 5;           % the size of the training/detection area proportional to the target size
params.search_area_scale_small_target = 6.5;   % % the size of the training/detection area proportional to the small target size
params.filter_max_area   = 50^2;        % the size of the training/detection area in feature grid cells

%   Learning parameters
params.learning_rate       = 0.0128;        % learning rate
params.output_sigma_factor = 1/16;		% standard deviation of the desired correlation output (proportional to target)

%   Detection parameters
params.interpolate_response  = 4;        % correlation score interpolation strategy: 0 - off, 1 - feature grid, 2 - pixel grid, 4 - Newton's method
params.newton_iterations     = 5;           % number of Newton's iteration to maximize the detection scores
				% the weight of the standard (uniform) regularization, only used when params.use_reg_window == 0
%   Scale parameters
params.number_of_scales =  5;
params.scale_step       = 1.01;

%   size, position, frames initialization
params.wsize    = [seq.init_rect(1,4), seq.init_rect(1,3)];
params.init_pos = [seq.init_rect(1,2), seq.init_rect(1,1)] + floor(params.wsize/2);
params.s_frames = seq.s_frames;
params.no_fram  = seq.endFrame - seq.startFrame + 1;
params.seq_st_frame = seq.startFrame;
params.seq_en_frame = seq.endFrame;
% params.ground_truth=seq.ground_truth;
name = seq.name(1:end-2);
params.ground_truth = seq.ground_truth;
%   ADMM parameters, # of iteration, and lambda- mu and betha are set in
%   the main function.
params.pe=[1,1,1];
params.admm_iterations = 3;
params.al_iteration = 2;
params.admm_3frame =32 ;
params.admm_lambda = 0.1;
params.admm_lambda1 = 0.2;
params.admm_lambda2 = 0.001;
params.alphaw = 1;
params.ifcompress=1;
params.w_init = 7;
%   Debug and visualization
params.visualization = 0;
params.show_regularization = 0;

%   Run the main function
BSTCF_optimized_VOT_baseline(params,videos,vid);
