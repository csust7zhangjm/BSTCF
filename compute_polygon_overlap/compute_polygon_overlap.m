function OP = compute_polygon_overlap(groundtruth,box,bounds)
if numel(groundtruth) > 4
     x1 = min(groundtruth(1:2:end));
     x2 = max(groundtruth(1:2:end));
     y1 = min(groundtruth(2:2:end));
     y2 = max(groundtruth(2:2:end));
     b1 = [x1, y1, x2, y2];
else
     b1 = [groundtruth(1:2), groundtruth(1:2) + groundtruth(3:4)];
end
b2=[box(1:2),box(1:2)+box(3:4)];
bb1=[max(b1(1:2),bounds(1:2)),min(b1(3:4),bounds(3:4))];
bb2=[max(b2(1:2),bounds(1:2)),min(b2(3:4),bounds(3:4))];
x=min(bb1(1),bb2(1));
y=min(bb1(2),bb2(2));
width = floor(max(bb1(3), bb2(3)) - x) + 1;
height = floor(max(bb1(4), bb2(4)) - y) + 1;
%Fixing crashes due to overflowed regions, a simple check if the ratio
%between the two bounding boxes is simply too big and the overlap would
%be 0 anyway.

a1 = (bb1(3) - bb1(1)) * (bb1(4) - bb1(2));
a2 = (bb2(3) - bb2(1)) * (bb2(4) - bb2(2));
if (a1 / a2 < 1e-10 || a2 / a1 < 1e-10 || width < 1 || height < 1)
    OP=0;
    return;
end
intersectionArea = computeIntersectionArea(bb1,bb2);            
OP = max(0,intersectionArea/(computeArea(bb1)+computeArea(bb2)-intersectionArea));
return