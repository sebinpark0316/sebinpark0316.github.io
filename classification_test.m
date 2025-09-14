% 단일 테스트 이미지 불러오기
imgPath = 'D:\종합설계프로젝트\ktx_raw\image_7.png';  % ★ 테스트 이미지 절대경로
img = imread(imgPath);
load('trainedResnet50_BagClassifier_640.mat', 'trainedNet');  % 640x640 입력 요구

% 모델 입력 크기로 리사이즈 (예: 224x224 또는 640x640 등 모델에 맞게)
inputSize = trainedNet.Layers(1).InputSize;
imgResized = imresize(img, inputSize(1:2));

% 이미지 분류
[label, score] = classify(trainedNet, imgResized);

% 결과 출력
disp("예측 결과: " + string(label));
disp("신뢰도: " + num2str(max(score)*100, '%.2f') + "%");

% 시각화 (선택 사항)
figure;
imshow(img);
title("예측: " + string(label) + " (" + num2str(max(score)*100, '%.1f') + "%)");