% This function implements the ASRCF tracker.

function [] = BSTCF_optimized_VOT_baseline(params,videos,vid)
%   Setting parameters for local use.
startframe = 1;
finishflag = 0;
num_frames = params.no_fram;
timeb = zeros(num_frames, 15);
rect_positionb = cell(num_frames, 1);
rect_positionb{1} = 1;
while(1)
    tic();
    search_area_scale   = params.search_area_scale;
    output_sigma_factor = params.output_sigma_factor;
    learning_rate       = params.learning_rate;
    filter_max_area     = params.filter_max_area;
    nScales             = params.number_of_scales;
    scale_step          = params.scale_step;
    interpolate_response = params.interpolate_response;
    alphaw=params.alphaw;
    update_interval=2;%����֡һ����  ԭ��Ϊ2֡��
    features    = params.t_features;
    video_path  = params.video_path;
    s_frames    = params.s_frames;
    [seq, ~] = load_video_info(video_path,startframe);
    params.wsize    = [seq.init_rect(1,4), seq.init_rect(1,3)];
    params.init_pos = [seq.init_rect(1,2), seq.init_rect(1,1)] + floor(params.wsize/2);
    pos         = floor(params.init_pos);
    target_sz   = floor(params.wsize);
    im1 = imread([video_path '/' s_frames{startframe}]);
    %im1 = imread([s_frames{1}]);
    visualization  = params.visualization;
    init_target_sz = target_sz;
    ifcompress=params.ifcompress;
    pe=params.pe;
    % use large sacle for small target
       if init_target_sz(1)*init_target_sz(2)<900&&(size(im1,1)*size(im1,2))/(init_target_sz(1)*init_target_sz(2))>180
           search_area_scale=6.5;
           pe=[0.1,1,0];
           params.admm_3frame = 0;
           ifcompress=0;
       end

    featureRatio = params.t_global.cell_size;
    search_area_pos = prod(init_target_sz / featureRatio * search_area_scale);

    % when the number of cells are small, choose a smaller cell size
    if isfield(params.t_global, 'cell_selection_thresh')
        if search_area_pos < params.t_global.cell_selection_thresh * filter_max_area
            params.t_global.cell_size = min(featureRatio, max(1, ceil(sqrt(prod(init_target_sz * search_area_scale)/(params.t_global.cell_selection_thresh * filter_max_area)))));

            featureRatio = params.t_global.cell_size;
            search_area_pos = prod(init_target_sz / featureRatio * search_area_scale);
        end
    end

    global_feat_params = params.t_global;

    if search_area_pos > filter_max_area
        currentScaleFactor = sqrt(search_area_pos / filter_max_area);
    else
        currentScaleFactor = 1.0;
    end

    % target size at the initial scale
    base_target_sz = target_sz / currentScaleFactor;

    % window size, taking padding into account
    switch params.search_area_shape
        case 'proportional'
            sz = floor( base_target_sz * search_area_scale);     % proportional area, same aspect ratio as the target
        case 'square'
            sz = repmat(sqrt(prod(base_target_sz * search_area_scale)), 1, 2); % square area, ignores the target aspect ratio
        case 'fix_padding'
            sz = base_target_sz + sqrt(prod(base_target_sz * search_area_scale) + (base_target_sz(1) - base_target_sz(2))/4) - sum(base_target_sz)/2; % const padding
        otherwise
            error('Unknown "params.search_area_shape". Must be ''proportional'', ''square'' or ''fix_padding''');
    end

    % set the size to exactly match the cell size
    sz = round(sz / featureRatio) * featureRatio;
    use_sz = floor(sz/featureRatio);

    % construct the label function- correlation output, 2D gaussian function,
    % with a peak located upon the target

    output_sigma = sqrt(prod(floor(base_target_sz/featureRatio))) * output_sigma_factor;
    rg           = circshift(-floor((use_sz(1)-1)/2):ceil((use_sz(1)-1)/2), [0 -floor((use_sz(1)-1)/2)]);
    cg           = circshift(-floor((use_sz(2)-1)/2):ceil((use_sz(2)-1)/2), [0 -floor((use_sz(2)-1)/2)]);
    [rs, cs]     = ndgrid( rg,cg);
    y            = exp(-0.5 * (((rs.^2 + cs.^2) / output_sigma^2)));
    yf           = fft2(y); %   FFT of y.


    if interpolate_response == 1
        interp_sz = use_sz * featureRatio;
    else
        interp_sz = use_sz;
    end

    % construct cosine window
    feature_sz_cell={use_sz,use_sz,use_sz};
      cos_window = cellfun(@(sz) single(hann(sz(1)+2)*hann(sz(2)+2)'), feature_sz_cell, 'uniformoutput', false);
      cos_window = cellfun(@(cos_window) cos_window(2:end-1,2:end-1), cos_window, 'uniformoutput', false);
    try
        im = imread([video_path '/img/' s_frames{startframe}]);
    catch
        try
            im = imread(s_frames{startframe});
        catch
            %disp([video_path '/' s_frames{1}])
            im = imread([video_path '/' s_frames{startframe}]);
        end
    end
    if size(im,3) == 3
        if all(all(im(:,:,1) == im(:,:,2)))
            colorImage = false;
        else
            colorImage = true;
        end
    else
        colorImage = false;
    end

    % compute feature dimensionality
    feature_dim = 0;
    for n = 1:length(features)

        if ~isfield(features{n}.fparams,'useForColor')
            features{n}.fparams.useForColor = true;
        end

        if ~isfield(features{n}.fparams,'useForGray')
            features{n}.fparams.useForGray = true;
        end

        if (features{n}.fparams.useForColor && colorImage) || (features{n}.fparams.useForGray && ~colorImage)
            feature_dim = feature_dim + features{n}.fparams.nDim;
        end
    end

    if size(im,3) > 1 && colorImage == false
        im = im(:,:,1);
    end

    if nScales > 0
        scale_exp = (-floor((nScales-1)/2):ceil((nScales-1)/2));
        scaleFactors = scale_step .^ scale_exp;
        min_scale_factor = scale_step ^ ceil(log(max(5 ./ sz)) / log(scale_step));
        max_scale_factor = scale_step ^ floor(log(min([size(im,1) size(im,2)] ./ base_target_sz)) / log(scale_step));
    end

    if interpolate_response >= 3
        % Pre-computes the grid that is used for socre optimization
        ky = circshift(-floor((use_sz(1) - 1)/2) : ceil((use_sz(1) - 1)/2), [1, -floor((use_sz(1) - 1)/2)]);
        kx = circshift(-floor((use_sz(2) - 1)/2) : ceil((use_sz(2) - 1)/2), [1, -floor((use_sz(2) - 1)/2)])';
        newton_iterations = params.newton_iterations;
    end

    % initialize the projection matrix (x,y,h,w)
    [ws,h,~]=size(im);
    time = 0;

    % allocate memory for multi-scale tracking
    multires_pixel_template = zeros(sz(1), sz(2), size(im,3), nScales, 'uint8');
    small_filter_sz = floor(base_target_sz/featureRatio);

    loop_frame = 1;

    timeb(startframe,1:3) = toc();

    for frame = startframe :num_frames
        %load image
        tic();
        try
            %im = imread([s_frames{frame}]);
            im = imread([video_path '/img/' s_frames{frame}]);
        catch
            try
                im = imread([s_frames{frame}]);
            catch
                im = imread([video_path '/' s_frames{frame}]);
            end
        end
        if size(im,3) > 1 && colorImage == false
            im = im(:,:,1);
        end


    %% main loop
        if frame > startframe
            for scale_ind = 1:nScales        
                multires_pixel_template(:,:,:,scale_ind) = ...
                get_pixels(im, pos, round(sz*currentScaleFactor*scaleFactors(scale_ind)), sz);                          
            end

            for scale_ind = 1:nScales
            xt_hc(:,:,:,scale_ind)=get_features(multires_pixel_template(:,:,:,scale_ind),features,global_feat_params);
                  xt_hcf(:,:,:,scale_ind)=fft2(bsxfun(@times,xt_hc(:,:,:,scale_ind),cos_window{1}));
            end    
               xt=extract_features(multires_pixel_template(:,:,:,3),use_sz,features,global_feat_params,frame,ifcompress,pe);
                   xtf=cellfun(@(feat_map, cos_window) fft2(bsxfun(@times,feat_map,cos_window)), xt(1:3), cos_window, 'uniformoutput', false);              
                   xtf=cat(3,xtf{1},xtf{2},xtf{3});
                   responsef=permute(sum(bsxfun(@times, conj(g_f), xtf), 3), [1 2 4 3]);
                  response_hcf=permute(sum(bsxfun(@times, conj(g_hcf), xt_hcf), 3), [1 2 4 3]); 

                  responsef=gather(responsef);
                  response_hcf=gather(response_hcf);

            % if we undersampled features, we want to interpolate the
            % response so it has the same size as the image patch
            if interpolate_response == 2
                % use dynamic interp size
                interp_sz = floor(size(y) * featureRatio * currentScaleFactor);
            end
            responsef_padded = resizeDFT2(responsef, interp_sz);
            responsehcf_padded = resizeDFT2(response_hcf, use_sz);
            % response in the spatial domain
            response = ifft2(responsef_padded, 'symmetric');
            responsehc = ifft2(responsehcf_padded, 'symmetric');
            % find maximum peak
            if interpolate_response == 3
                error('Invalid parameter value for interpolate_response');
            elseif interpolate_response == 4

               [~, ~, sind] = resp_newton(responsehc, responsehcf_padded, newton_iterations, ky, kx, use_sz);
               [disp_row, disp_col, ~] = resp_newton(response, responsef_padded, newton_iterations, ky, kx, use_sz);

            else
                [row, col, sind] = ind2sub(size(response), find(response == max(response(:)), 1));
                disp_row = mod(row - 1 + floor((interp_sz(1)-1)/2), interp_sz(1)) - floor((interp_sz(1)-1)/2);
                disp_col = mod(col - 1 + floor((interp_sz(2)-1)/2), interp_sz(2)) - floor((interp_sz(2)-1)/2);
            end
            % calculate translation
            switch interpolate_response
                case 0
                    translation_vec = round([disp_row, disp_col] * featureRatio * currentScaleFactor * scaleFactors(sind));
                case 1
                    translation_vec = round([disp_row, disp_col] * currentScaleFactor * scaleFactors(sind));
                case 2
                    translation_vec = round([disp_row, disp_col] * scaleFactors(sind));
                case 3
                    translation_vec = round([disp_row, disp_col] * featureRatio * currentScaleFactor * scaleFactors(sind));
                case 4
                    translation_vec = round([disp_row, disp_col] * featureRatio * currentScaleFactor * scaleFactors(sind));
            end

            % set the scale
            currentScaleFactor = currentScaleFactor * scaleFactors(sind);
            % adjust to make sure we are not to large or to small
            if currentScaleFactor < min_scale_factor
                currentScaleFactor = min_scale_factor;
            elseif currentScaleFactor > max_scale_factor
                currentScaleFactor = max_scale_factor;
            end

            % update position
            old_pos = pos;
            pos = pos + translation_vec;
            if pos(1)<0||pos(2)<0||pos(1)>size(im,1)||pos(2)>size(im,2)
                pos=old_pos;
                learning_rate=0;
            end
        end
         target_sz = floor(base_target_sz * currentScaleFactor);

        %save position and calculate FPS
        rect_position = [pos([2,1]) - floor(target_sz([2,1])/2), target_sz([2,1])];



      if frame==startframe   
        % extract training sample image region
            pixels = get_pixels(im,pos,round(sz*currentScaleFactor),sz);
            pixels = uint8(gather(pixels));
             x=extract_features(pixels,use_sz,features,global_feat_params,frame,ifcompress,pe);
             xf=cellfun(@(feat_map, cos_window) fft2(bsxfun(@times,feat_map,cos_window)), x(1:3), cos_window, 'uniformoutput', false);
             xf=cat(3,xf{1},xf{2},xf{3});
      else
    % use detection features
             shift_samp_pos = 2*pi * translation_vec ./ (scaleFactors(sind)*currentScaleFactor * sz);
             xf = shift_sample(xtf, shift_samp_pos, kx', ky');
      end
      if colorImage == false
        xhcf=xf(:,:,1:31);
      else
        xhcf=xf(:,:,1:41);
      end

        if (frame == startframe)
             model_xf =xf;
             model_xhcf=xhcf;
             model_w=gpuArray(construct_regwindow(use_sz,small_filter_sz));
    %             model_w=construct_regwindow(use_sz,small_filter_sz); 
        elseif frame==startframe||mod(frame,update_interval)==0
    %          model_xf = ((1 - params.learning_rate ) * model_xf) + (params.learning_rate  * xf);
             model_xf = ((1 - 10/params.no_fram) * model_xf) + (10/params.no_fram  * xf);
            % model_xf = xf;
    %          model_xhcf = ((1 - params.learning_rate ) * model_xhcf) + (params.learning_rate  * xhcf);
              model_xhcf = ((1 - 10/params.no_fram ) * model_xhcf) + (10/params.no_fram  * xhcf);
        end

    % ADMM solution   ADMM�Ż� 
        if (frame==startframe||mod(frame,update_interval)==0) 
        w = gpuArray(params.w_init*single(ones(use_sz)));
    %     w = params.w_init*single(ones(use_sz));
        %%%
        if frame == startframe
            h_f3 = w;
        elseif frame ==startframe + 2
            h_f3 = h_f;
        else 
            h_f3 = h_f;
        end
        %%%
       % ADMM solution for localization
    %     [g_f,h_f]=ADMM_solve_h(params,use_sz,model_xf,yf,small_filter_sz,w,model_w,frame); % hֵ
    %     for iteration = 1:params.al_iteration-1
    %         [w]=ADMM_solve_w(params,use_sz,model_w,h_f);
    %         [g_f,h_f]=ADMM_solve_h(params,use_sz,model_xf,yf,small_filter_sz,w,model_w,frame);
    %     end

        %%%
        [g_f,h_f]=ADMM_solve_h(params,use_sz,model_xf,yf,small_filter_sz,w,model_w,frame,h_f3); % hֵ
        for iteration = 1:params.al_iteration-1
            [w]=ADMM_solve_w(params,use_sz,model_w,h_f);
            [g_f,h_f]=ADMM_solve_h(params,use_sz,model_xf,yf,small_filter_sz,w,model_w,frame,h_f3);
        end
        %%%

        model_w=alphaw*w+(1-alphaw)*model_w;
       % ADMM solution for scale estimation �߶�Ԥ��
    %     h_ff1 = h_f(:,:,1:31);
        [g_hcf]=ADMM_base(params,use_sz,model_xhcf,xhcf,yf,small_filter_sz,frame,w);

        end

        if numel(rect_position) > 4
            % all x,y points shifted by 1
            rect_position = rect_position - 1;
        else
            % shift x,y by 1
            rect_position(1:2) = rect_position(1:2) - 1;
        end


        timeb(frame,1:3) = toc();

        %ground_truth=params.ground_truth(frame,:);
        if frame > startframe
            OP = compute_polygon_overlap(params.ground_truth(frame,:),double(rect_position),double([0,0,h,ws]));
            if OP==0
                if num_frames-frame>4
                    rect_positionb{frame}=2;
                    zero4 = num2cell(zeros(4,1));
                    rect_positionb(frame+1:frame+4,1)=zero4;
                    timeb(frame+1:frame+4,1:3) = 0/0;% ����Nan
                    rect_positionb{frame+5}=1;
                    startframe = frame+5;
                    clear xt_hc;
                    clear xt_hcf;
                    % clear response_hcf;
                    break;
                else
                    rect_positionb{frame}=2;
                    zeron = num2cell(zeros(num_frames-frame,1));
                    rect_positionb(frame+1:num_frames,1)=zeron;
                    timeb(frame+1:num_frames,1:3) = 0/0;% ����Nan
                    finishflag=1;
                    break;
                end
            else
                rect_positionb{frame}=double(rect_position);
            end
        end
    %%    visualization
        if visualization == 1
            show_adaptive_regularization;
            rect_position_vis = [pos([2,1]) - target_sz([2,1])/2, target_sz([2,1])];
            im_to_show = double(im)/255;
            if size(im_to_show,3) == 1
                im_to_show = repmat(im_to_show, [1 1 3]);
            end
            if frame == 1
                fig_handle = figure('Name', 'Tracking');
                imagesc(im_to_show);
                hold on;
                rectangle('Position',rect_position_vis, 'EdgeColor','g', 'LineWidth',2);
                text(10, 10, int2str(frame), 'color', [0 1 1]);
                hold off;
                axis off;axis image;set(gca, 'Units', 'normalized', 'Position', [0 0 1 1])
            else
                resp_sz = round(sz*currentScaleFactor*scaleFactors(scale_ind));
                xs = floor(old_pos(2)) + (1:resp_sz(2)) - floor(resp_sz(2)/2);
                ys = floor(old_pos(1)) + (1:resp_sz(1)) - floor(resp_sz(1)/2);
                ground_truth=params.ground_truth(frame,:);
                if numel(ground_truth) > 4
                    bb8 = round(ground_truth(:));
                    x1 = round(min(bb8(1:2:end)));
                    x2 = round(max(bb8(1:2:end)));
                    y1 = round(min(bb8(2:2:end)));
                    y2 = round(max(bb8(2:2:end)));
                    ground_truth = round([x1, y1, x2 - x1, y2 - y1]);
                end
                figure(fig_handle);
                imagesc(im_to_show);
                hold on;
                resp_handle = imagesc(xs, ys, fftshift(response(:,:,1))); colormap hsv;
                alpha(resp_handle, 0.2);
                rectangle('Position',rect_position_vis, 'EdgeColor','g', 'LineWidth',2);
                rectangle('Position',ground_truth, 'EdgeColor','r', 'LineWidth',2);
                text(20, 30, ['# Frame : ' int2str(loop_frame) ' / ' int2str(num_frames)], 'color', [1 0 0], 'BackgroundColor', [1 1 1], 'fontsize', 16);
                text(20, 60, ['FPS : ' num2str(1/(time/loop_frame))], 'color', [1 0 0], 'BackgroundColor', [1 1 1], 'fontsize', 16);

                hold off;

            end
            drawnow
        end


        loop_frame = loop_frame + 1;
    end
    if (finishflag == 1)||(frame == num_frames)
        break;
    end
end
%   save resutls.
baselinepath=['E:/BSTCF/baseline/',videos{vid}];%results save path
mkdir(baselinepath);
dlmwrite([baselinepath '/' videos{vid} '_001.txt'], rect_positionb{1},'newline','pc');
dlmwrite([baselinepath '/' videos{vid} '_002.txt'], rect_positionb{1},'newline','pc');
dlmwrite([baselinepath '/' videos{vid} '_003.txt'], rect_positionb{1},'newline','pc');
for fid=2:num_frames
    dlmwrite([baselinepath '/' videos{vid} '_001.txt'], rect_positionb{fid},'-append','newline','pc');
    dlmwrite([baselinepath '/' videos{vid} '_002.txt'], rect_positionb{fid},'-append','newline','pc');
    dlmwrite([baselinepath '/' videos{vid} '_003.txt'], rect_positionb{fid},'-append','newline','pc');
end
dlmwrite([baselinepath '/' videos{vid} '_time.txt'], timeb,'newline','pc', 'precision',5);
end
