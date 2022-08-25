close all
clear all
addpath('WorkspacesDemo1');

load('Workspace_line.mat');
% load('workspace2_ethan.mat');
figure(99);
for m = 2:5
    
    subplot(2,2,m-1);
    I = rgb2gray(imageCircBuff(:,:,:,m));
    imshow(imageCircBuff(:,:,:,m));
    tic
    [out_lines] = getLine(imageCircBuff(:,:,:,m));
    toc
    hold on
    for k = 1:length(out_lines)
    %          xy = [lines(k).point1; lines(k).point2]; % uncomment to plot all lines
     xy = [out_lines(k).point1; out_lines(k).point2];
     plot(xy(:,1),xy(:,2),'LineWidth',2,'Color','cyan');

     % Plot beginnings and ends of lines
     plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
     plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');
    end
    %[lines] = findEdgesThick(BW, 1);
end 
% subplot(221); imshow(imageCircBuff(:,:,:,1));
% subplot(222); imshow(imageCircBuff(:,:,:,2));
% subplot(223); imshow(imageCircBuff(:,:,:,3));
% subplot(224); imshow(imageCircBuff(:,:,:,5));



% [xyzPoints,errors,cameraPoses] = str_from_mot(imageCircBuff, rotCircBuff, posCircBuff, cameraParams);
% figure
% z = xyzPoints(:,3);
% idx = errors < 5 & z > 0 & z < 20;
% pcshow(xyzPoints(idx, :),'VerticalAxis','y','VerticalAxisDir','down','MarkerSize',30);
% hold on
% plotCamera(cameraPoses, 'Size', 0.1);
% hold off



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [odom_sub, imu_sub, image_sub] = init_Perception(TurtleBot_Topic)
%init_Perception - starts up tasks for subscibers in ROS 
    if ismember(TurtleBot_Topic.odom, rostopic('list'))
    %     use rostopic info topicname to detemine the message type
        odom_sub = rossubscriber(TurtleBot_Topic.odom, 'nav_msgs/Odometry');
    else
        error('no odom member'); 
    end
% read imu
    if ismember(TurtleBot_Topic.imu, rostopic('list'))
        imu_sub = rossubscriber(TurtleBot_Topic.imu, 'sensor_msgs/Imu');
    else
        error('no imu member'); 
    end
%read images
    % images captured by Pi camera, if you are using Gazebo, the topic list is different.
    if ismember(TurtleBot_Topic.picam, rostopic('list'))
        image_sub = rossubscriber(TurtleBot_Topic.picam);
    else
        error('no picam member'); 
    end
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [velocity_pub, velocity_msg] = init_Motion(TurtleBot_Topic)
    if ismember(TurtleBot_Topic.vel, rostopic('list'))
          velocity_pub = rospublisher(TurtleBot_Topic.vel, 'geometry_msgs/Twist');
    %     velocity_sub = rossubscriber('cmd_vel', 'geometry_msgs/Twist');
    end
    velocity_msg = rosmessage(velocity_pub);
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [C] = TurtleBot3_Image(image_sub)
    image_compressed = receive(image_sub);
    image_compressed.Format = 'bgr8; jpeg compressed bgr8';
    C = readImage(image_compressed); 
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [robot_Position, robot_Rotation] = TurtleBot3_Odom(odom_sub, imu_sub)
    odom_data = receive(odom_sub);
    imu_data = receive(imu_sub);
    robot_Position = [odom_data.Pose.Pose.Position.X, odom_data.Pose.Pose.Position.Y, odom_data.Pose.Pose.Position.Z];
    robot_Orientation1 = [imu_data.Orientation.W, imu_data.Orientation.X, imu_data.Orientation.Y, imu_data.Orientation.Z];
    robot_Rotation = quat2rotm(robot_Orientation1);
end

function [xyzPoints,errors, cameraPoses] = str_from_mot(images, rotations, locations, cameraParams)
    % Compute features for the first image.
    I = rgb2gray(images(:,:,:, 1));
    I = undistortImage(I,cameraParams);
    pointsPrev = detectSURFFeatures(I);
    [featuresPrev,pointsPrev] = extractFeatures(I,pointsPrev);
    
    %Create a viewSet object.
    vSet = viewSet;
    vSet = addView(vSet, 1,'Points',pointsPrev,'Orientation',...
                   rotations(:,:,1),'Location',locations(1,:));
    for i = 2:size(images, 4)
      I = rgb2gray(images(:,:,:, i));
      %I = undistortImage(I, cameraParams); Already done
      points = detectSURFFeatures(I);
      [features, points] = extractFeatures(I, points);
      vSet = addView(vSet,i,'Points',points,'Orientation',...
                     rotations(:,:,i),'Location',locations(i,:));
      pairsIdx = matchFeatures(featuresPrev,features,'MatchThreshold',5);
      vSet = addConnection(vSet,i-1,i,'Matches',pairsIdx);
      featuresPrev = features;
    end
    % Find point tracks.
    tracks = findTracks(vSet);
    % Get camera poses.
    cameraPoses = poses(vSet);
    %Find 3-D world points.
    [xyzPoints,errors] = triangulateMultiview(tracks,cameraPoses,cameraParams);
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [C_fore_mask,rng] = foreground_mask(I)
%% Foreground detection function, detects the foreground based on the
% largest blob appearing in the image as found by bwboundaries with
% noholes.
% Input:
%       C               1 channel grayscale image
% Outputs: 
%       C_fore_mask     image mask with foreground as 1's
    BW = imbinarize(I); % Threshold image according to otsu's method
    [B, ~] = bwboundaries(BW, 'noholes'); 
    [~, index] = maxk(cellfun('length', B),3);
    C_fore_mask = zeros(size(BW),'uint8'); 
    if max(max(B{index(1)}(:,1))) == size(BW, 1)
        rng = [min(B{index(1)}(:,1)), max(B{index(1)}(:,1)); min(B{index(1)}(:,2)),max(B{index(1)}(:,2))];
        
    elseif max(max(B{index(2)}(:,1))) == size(BW, 1)
        rng = [min(B{index(2)}(:,1)), max(B{index(2)}(:,1)); min(B{index(2)}(:,2)),max(B{index(2)}(:,2))];
        
    elseif max(max(B{index(3)}(:,1))) == size(BW, 1)
        rng = [min(B{index(3)}(:,1)), max(B{index(3)}(:,1)); min(B{index(3)}(:,2)),max(B{index(3)}(:,2))];
        
    else
        rng = [215 480; 1 640];
    end
    C_fore_mask((rng(1,1)+10):rng(1,2), rng(2,1):rng(2,2)) = 1; 
    C_fore_mask = logical(C_fore_mask);
%     figure;
%     imshow(logical(C_fore_mask));
end

function [lines] = getLine(C)
%% Do preprocessing/noise reduction
    %subplot(2,2,m);
    C = histeq(C);
    I = rgb2gray(C);
    I = histeq(I);
    [fore_mask, rng] = foreground_mask(I); 
%     if sum(sum(fore_mask)) < 
%     
%     end
    J = histeq(I);
    J = J.*uint8(fore_mask);
    J = histeq(J);
% Second round of reduction
    %imshowpair(I,J,'montage')
    BW = imbinarize(J, .9); 
    specular_mask = imgaussfilt(uint8(BW), 5);
    M = J.*specular_mask;
    %imshowpair(J,M,'montage')

    N = histeq(M);%.*specular_mask.*fore_mask;
    %imshowpair(M,N,'montage')

% Third round    
    %BW = imbinarize(N, [0.9, 0.97]); 
    sumB4 = sum(sum(N)); 
    sumNow =  sum(sum(N)); 
    dec = 0;
    BWadapt = imbinarize(N, 'adaptive','Sensitivity',0.6+dec);
    Q = N.*uint8(BWadapt);
    target =  sum(sum(N.*Q))/sumB4/25;
    P = N;
    while (sumNow/sumB4 > target) && (dec> -0.55)
        BWadapt = imbinarize(N, 'adaptive','Sensitivity',0.6+dec);
        dec = dec - 0.01;
        %BWadapt =imgaussfilt(uint8(BWadapt), 5);
        P = N.*uint8(BWadapt);
        sumNow = sum(sum(P));
        %P = histeq(P);
        %BW = imbinarize(P, .9); 
        %imshow(BWadapt)
        %imshow(P)
    end
   
 %% Detected boundaries for reduced image with only specular objects   
 BW_filt = logical(uint8(medfilt2(BWadapt)).*uint8(specular_mask).*uint8(fore_mask));   
 %imshow(BW_filt)
 [B,L] = bwboundaries(BW_filt,'noholes');
    %imshow(B)
    %title('Labeled Image')
    %imshow(label2rgb(L, @jet, [.5 .5 .5]))
    
% Turn boundaries into masks and calc selection metrics
    masks = nan(size(BW,1),size(BW,2), length(B)); 
    edges = nan(size(BW,1),size(BW,2), length(B));
    sums = nan(length(B),1);
    size_B = cellfun('length',B);
    num_elts = 5;%ceil(length(B)*1/3) % hopefully reduce comp time. 
    [bigBs, idx_B] = maxk(size_B, num_elts);
    B = B(idx_B); 
    if length(B) == 1
        my_mask = zeros(size(BW));
        inds = sub2ind(size(my_mask), B{1}(:,1), B{1}(:,2));
        my_mask(inds) = 1; 
        edges =cat(3, my_mask, edges(:,:, 1:end-1));
        BW = imfill(my_mask,'holes');
        masks = my_mask; 
        sums = sum(sum(BW));

    else 
        for k = 1:length(B)
            my_mask = zeros(size(BW));
            inds = sub2ind(size(my_mask), B{k}(:,1), B{k}(:,2));
            my_mask(inds) = 1; 
            edges =cat(3, my_mask, edges(:,:, 1:end-1));
            BW = imfill(my_mask,'holes');
            masks =cat(3, BW, masks(:,:, 1:end-1));
            sums =cat(1, sum(sum(BW)), sums(1:end-1));
            imshow(BW)
        end
    end
    
%% Select "best" mask by size - future by size and degree of specularness
    [sorted_sums, I_sum] = sort(sums); 
    
    % Just choose the biggest
    [~, candidate_1] = max(sums); 
%     figure(1);
%     subplot(1,1,1)
%     imshow(edges(:,:,candidate_1));
%% Detect lines from calcuated boundaries (no canny needed) 
    [lines1, all_lines] = findEdgesThick(edges(:,:,candidate_1), 1);
    lines = checkLines(lines1);
    if ~isempty(lines1)
        long_line = elongateLines(lines, rng, 1);
        lines = long_line;
    end
end


% function [good_lines] = checkLines(lines)
% bad_lines = zeros(size(lines)); % bad line means 1   
%     for k = 1:length(lines)
%         % bottom horz case 
%         A =(lines(k).point1(2) == 480 || lines(k).point2(2) == 480);
%         % top horz case
%         B =(lines(k).point1(2) == 1 || lines(k).point2(2) == 1);
%         % left vert case
%         C =(lines(k).point1(1) == 1 || lines(k).point2(1) == 1);
%         % right vert case
%         D =(lines(k).point1(1) == 640 || lines(k).point2(1) == 640);
%         % left vert case
%         %E =(lines(k).point1(1) == 0 || lines(k).point2(1) == 0);
%     
%         bad_lines(k) = (A||B||C||D);
%     end 
%  good_lines = lines(~bad_lines); 
% end 


function [long_line, lineM, lineC] = elongateLines(lines, rng, verbose)
     try 
        % Compute the length of each detected line
      lines_tb = struct2table(lines);
      lineLength = zeros(length(lines),1); 
      points_1 = lines_tb.point1;
      points_2 = lines_tb.point2;
      % Find most extreme line points 
      [~, min_p1_index] = min(points_1(:,1));
      [~, max_p2_index] = max(points_2(:,1));
      
      point1 = lines(min_p1_index).point1; % left most point detected
      point2 = lines(max_p2_index).point2; % right most point detected 
      
      % Find the slope for the most extreme points on the line 
      lineM = (point2(2) -  point1(2))./(point2(1) - point1(1));
      lineC =  (point2(2)) - lineM*(point2(1));
      
      % Find the rho/theta for the most extreme points on the line 
      lineTheta = -atan2(1, lineM);
      lineRho = lineC * sin(lineTheta);
      
      % Compare rho and theta...
      deg2rad(lines(min_p1_index).theta)
      lines(min_p1_index).rho
      
      x = 1:640;
      y = lineM.*x+lineC; 
      y = y(y>215);  % y(y>rng(1,1))
      x = ceil((y - lineC)./lineM);
      if isnan(sum(sum(x)))
        long_line = []; 
        lineM = NaN;  
        lineC = NaN;
        return;
      end 
      for k = 1:length(lines)
        lineLength(k) = norm(lines_tb.point1(k,:) -  lines_tb.point2(k,:));
      end
       longest_lines = lines(lineLength == max(lineLength));
       longest_line = longest_lines(1);
    
    field1 = 'point1';  value1 = [0,0];
    field2 = 'point2';  value2 = [0, 0];
    field3 = 'theta';  value3 = 0;
    field4 = 'rho';  value4 = 0;
    long_line = struct(field1,value1,field2,value2,field3,value3,field4,value4);
    
    long_line.point1 = [x(1), y(1)];
    long_line.point2 = [x(end), y(end)];           
    long_line.theta = lineTheta; 
    long_line.rho = lineRho; 
    
    if (verbose == 1) 
        hold on; 
        xy = [long_line.point1; long_line.point2];
        % Plot beginnings and ends of lines
        plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
        plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');  
        plot(x,y,'LineWidth',2,'Color','cyan');
        
%         for k = 1:length(lines)
%             %          xy = [lines(k).point1; lines(k).point2]; % uncomment to plot all lines
%             xy = [lines(k).point1; lines(k).point2];
%             plot(xy(:,1),xy(:,2),'LineWidth',2,'Color','blue');
% 
%             % Plot beginnings and ends of lines
%             plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
%             plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');
%         end
    end
     catch
        long_line = []; 
        lineM = NaN;  
        lineC = NaN;
     end 
end