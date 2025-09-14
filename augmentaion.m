% 증강 대상 폴더
inputFolder = 'C:\Users\ch082\OneDrive\바탕 화면\종설프3\resized_images_nobag';    
outputFolder = 'C:\Users\ch082\OneDrive\바탕 화면\종설프3\new_augmented_nobag';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

imgFiles = dir(fullfile(inputFolder, '*.png'));
numFiles = length(imgFiles);

numAugPerImage = 10;

for i = 1:numFiles
    imgPath = fullfile(inputFolder, imgFiles(i).name);
    img = imread(imgPath);

    for j = 1:numAugPerImage
        augImg = im2double(img);

        % 회전
        angle = randi([-45, 45]);
        augImg = imrotate(augImg, angle, 'bilinear', 'crop');

        % 평행 이동
        tx = randi([-20, 20]);
        ty = randi([-20, 20]);
        tform = affine2d([1 0 0; 0 1 0; tx ty 1]);
        augImg = imwarp(augImg, tform, 'OutputView', imref2d(size(augImg)));

        % 수평 뒤집기
        if rand > 0.5
            augImg = fliplr(augImg);
        end

        % 밝기 조정
        brightnessFactor = 0.7 + 0.6 * rand;
        augImg = augImg * brightnessFactor;

        % 색상 왜곡 (HSV 변환 후 채도, 색조 변화)
        hsv = rgb2hsv(augImg);
        hsv(:,:,1) = mod(hsv(:,:,1) + 0.1*randn, 1);         % hue 변화
        hsv(:,:,2) = min(max(hsv(:,:,2) * (0.8 + 0.4*rand), 0), 1);  % saturation 변화
        augImg = hsv2rgb(hsv);

        % 가우시안 노이즈 추가
        if rand > 0.5
            augImg = imnoise(augImg, 'gaussian', 0, 0.005);
        end

        % 리사이즈 & 크롭/패딩
        scale = 0.9 + 0.2 * rand;
        augImg = imresize(augImg, scale);
        augImg = centerCropOrPad(im2uint8(augImg), size(img,1:2));

        % 저장
        [~, name, ext] = fileparts(imgFiles(i).name);
        outFileName = sprintf('%s_aug%d%s', name, j, ext);
        imwrite(augImg, fullfile(outputFolder, outFileName));
    end
end

function out = centerCropOrPad(in, targetSize)
    inSize = size(in);
    if length(inSize) < 3
        inSize(3) = 1;
    end
    out = zeros([targetSize, inSize(3)], 'like', in);

    % 중앙 crop 또는 pad
    rowStart = max(1, floor((inSize(1) - targetSize(1))/2) + 1);
    rowEnd   = min(inSize(1), rowStart + targetSize(1) - 1);
    colStart = max(1, floor((inSize(2) - targetSize(2))/2) + 1);
    colEnd   = min(inSize(2), colStart + targetSize(2) - 1);

    rows = 1:(rowEnd - rowStart + 1);
    cols = 1:(colEnd - colStart + 1);
    out(rows, cols, :) = in(rowStart:rowEnd, colStart:colEnd, :);
end
