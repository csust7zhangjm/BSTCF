% This is the demo script for ASRCF

clear;
clc;
close all;
setup_path();

% get seq information
base_path  = 'E:\BSTCF\seq';
video_path = [base_path '\MotorRolling'];
[seq, ground_truth] = load_video_info(video_path, 1);
video = 'FaceOcc1';
seq.name = 'FaceOcc1'
seq.startFrame = 1;
seq.endFrame = seq.len;
seq.ground_truth=ground_truth;

gt_boxes = [ground_truth(:,1:2), ground_truth(:,1:2) + ground_truth(:,3:4) - ones(size(ground_truth,1), 2)];

% Run ASRCF- main function
results = run_BSTCF(seq, video_path);

%   compute the OP
pd_boxes = results.res;
pd_boxes = [pd_boxes(:,1:2), pd_boxes(:,1:2) + pd_boxes(:,3:4) - ones(size(pd_boxes,1), 2)  ];
OP = zeros(size(gt_boxes,1),1);
for i=1:size(gt_boxes,1)
    b_gt = gt_boxes(i,:);
    b_pd = pd_boxes(i,:);
    OP(i) = computePascalScore(b_gt,b_pd);
end
OP_vid = sum(OP >= 0.5) / numel(OP);
FPS_vid = results.fps;
display([video  '---->' '   FPS:   ' num2str(FPS_vid)   '    op:   '   num2str(OP_vid)]);

