% This is the script to get tracking results on the VOT dataset for BSTCF

clear;
clc;
close all;
setup_path();
addpath('./compute_polygon_overlap/');
% get seq information
base_path  = 'E:/vot2016/';
%VOT2016
%{
videos = {'ants1','ants3','bag','ball1','ball2','basketball','birds1','blanket','bmx','bolt1','bolt2',...
'book','butterfly','car1','conduction1','crabs1','crossing','dinosaur','drone1','drone_across','drone_flip',...
'fernando','fish1','fish2','fish3','flamingo1','frisbee','girl','glove','godfather','graduate','gymnastics1',...
'gymnastics2','gymnastics3','hand','handball1','handball2','helicopter','iceskater1','iceskater2','leaves',...
'matrix','motocross1','motocross2','nature','pedestrain1','rabbit','racing','road','shaking','sheep',...
'singer2','singer3','soccer1','soccer2','soldier','tiger','traffic','wiper','zebrafish1'};
%}
%VOT2018
videos ={  'bag','ball1','ball2','basketball','birds1','birds2','blanket','bmx','bolt1',...
           'bolt2','book','butterfly','car1','car2','crossing','dinosaur','fernando','fish1',...
           'fish2','fish3','fish4','girl','glove','godfather','graduate','gymnastics1',...
           'gymnastics2','gymnastics3','gymnastics4','hand','handball1','handball2',...
           'helicopter','iceskater1','iceskater2','leaves','marching','matrix','motocross1',...
           'motocross2','nature','octopus','pedestrian1','pedestrian2','rabbit','racing',...
           'road','shaking','sheep','singer1','singer2','singer3','soccer1','soccer2',...
           'soldier','sphere','tiger','traffic','tunnel','wiper'};
       
for vid = 1:numel(videos)
    close all;
    disp(videos{vid})
    video_path = [base_path ,videos{vid},'/'];
    startframe = 1;
    [seq, ground_truth] = load_video_info_VOT(video_path,startframe);
    seq.name = videos{vid};
    seq.startFrame = 1;
    seq.endFrame = seq.len;
    seq.ground_truth=ground_truth;

    % Run ASRCF- main function
    run_BSTCF_VOT(seq, video_path, videos , vid);
end



