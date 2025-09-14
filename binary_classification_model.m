%% 1. 데이터셋 준비
trainFolder = 'D:\종합설계프로젝트\dataset\train';
valFolder = 'D:\종합설계프로젝트\dataset\val';

imdsTrain = imageDatastore(trainFolder, ...
    'IncludeSubfolders', true, ...
    'LabelSource', 'foldernames');

imdsVal = imageDatastore(valFolder, ...
    'IncludeSubfolders', true, ...
    'LabelSource', 'foldernames');

%% 2. 이미지 입력 크기 설정 (640x640 유지)
inputSize = [640 640 3];

augTrain = augmentedImageDatastore(inputSize(1:2), imdsTrain);
augVal   = augmentedImageDatastore(inputSize(1:2), imdsVal);

%% 3. 사전학습된 ResNet-50 불러오기 및 수정
% 1. 원래 네트워크 불러오기
net = resnet50;
lgraph = layerGraph(net);

% 2. 원래 입력 계층 이름 확인 후 제거
lgraph = replaceLayer(lgraph, 'input_1', imageInputLayer([640 640 3], 'Name', 'input_1'));

% 3. 마지막 세 개 계층 제거
lgraph = removeLayers(lgraph, {'fc1000','fc1000_softmax','ClassificationLayer_fc1000'});

% 4. 새로운 분류기 레이어 추가
numClasses = numel(categories(imdsTrain.Labels));
newLayers = [
    fullyConnectedLayer(numClasses, 'Name','fc_bag', ...
        'WeightLearnRateFactor',10, 'BiasLearnRateFactor',10)
    softmaxLayer('Name','softmax')
    classificationLayer('Name','classoutput')];

% 5. 레이어 연결
lgraph = addLayers(lgraph, newLayers);
lgraph = connectLayers(lgraph, 'avg_pool', 'fc_bag');


%% 4. 학습 옵션
options = trainingOptions('sgdm', ...
    'MiniBatchSize', 8, ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-4, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', augVal, ...
    'ValidationFrequency', 30, ...
    'Verbose', false, ...
    'Plots', 'training-progress');

%% 5. 네트워크 학습
trainedNet = trainNetwork(augTrain, lgraph, options);

%% 6. 저장
save('trainedResNet50_BagClassifier_640.mat', 'trainedNet');
