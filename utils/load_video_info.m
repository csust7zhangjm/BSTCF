function [seq, ground_truth] = load_video_info(video_path,startframe,videoname)

ground_truth = dlmread([video_path '/groundtruth.txt']);
%ground_truth = dlmread([video_path '/' videoname '_gt.txt']);
%seq.format = 'otb';
seq.len = size(ground_truth, 1);
seq.init_rect = ground_truth(startframe,:);

if numel(seq.init_rect) > 4
% all x,y points shifted by 1
    seq.init_rect = seq.init_rect + 1;
else
    % shift x,y by 1
    seq.init_rect(1:2) = seq.init_rect(1:2) + 1;
end

if numel(seq.init_rect) > 4
    bb8 = round(seq.init_rect(:));
    x1 = round(min(bb8(1:2:end)));
    x2 = round(max(bb8(1:2:end)));
    y1 = round(min(bb8(2:2:end)));
    y2 = round(max(bb8(2:2:end)));
    seq.init_rect = round([x1, y1, x2 - x1, y2 - y1]);
end
img_path = [video_path '\img'];

% if exist([img_path num2str(1, '%04i.png')], 'file'),
%     img_files = num2str((1:seq.len)', [img_path '%04i.png']);
% elseif exist([img_path num2str(1, '%04i.jpg')], 'file'),
%     img_files = num2str((1:seq.len)', [img_path '%04i.jpg']);
% elseif exist([img_path num2str(1, '%04i.bmp')], 'file'),
%     img_files = num2str((1:seq.len)', [img_path '%04i.bmp']);
% else
%     error('No image files to load.')
% end
img_files = dir(fullfile(img_path, '*.jpg'));
img_files = {img_files.name};
seq.s_frames = cellstr(img_files);

end

