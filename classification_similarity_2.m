function classification_similarity_2()
    %===============================
    % 사용자 설정
    %===============================
    boardingImgPath = 'C:\Users\ch082\OneDrive\바탕 화면\종설프3\ktx_8\image_1.png';
    exitingImgPath  = 'C:\Users\ch082\OneDrive\바탕 화면\종설프3\image_11.png';
    threshold = 0.7;

    %===============================
    % 모델 불러오기
    %===============================
    similarityNet = resnet50;  % 특징 추출용
    load('trainedResnet50_BagClassifier_v2_640.mat', 'trainedNet');  % 가방 분류기

    %===============================
    % 이미지 불러오기
    %===============================
    imgBoarding_original = imread(boardingImgPath);
    imgExiting_original  = imread(exitingImgPath);

    %===============================
    % 전처리 (각 네트워크용 리사이즈)
    %===============================
    inputSizeSim = similarityNet.Layers(1).InputSize;
    imgBoardingSim = imresize(imgBoarding_original, inputSizeSim(1:2));
    imgExitingSim  = imresize(imgExiting_original,  inputSizeSim(1:2));

    %===============================
    % Step 1: 동일 인물 여부 판단
    %===============================
    f1 = activations(similarityNet, imgBoardingSim, 'avg_pool', 'OutputAs', 'rows');
    f2 = activations(similarityNet, imgExitingSim,  'avg_pool', 'OutputAs', 'rows');
    similarity = dot(f1, f2) / (norm(f1) * norm(f2) + eps);
    isSamePerson = similarity > threshold;

    %===============================
    % Step 2: 결과 처리
    %===============================
    if ~isSamePerson
        % 시각화 (단순 비교만)
        figure('Name', 'Similarity Check Result', 'NumberTitle', 'off');
        subplot(1,2,1);
        imshow(imgBoarding_original);
        title('탑승 이미지');

        subplot(1,2,2);
        imshow(imgExiting_original);
        title('하차 이미지');

        sgtitle({sprintf('Cosine Similarity: %.4f → 동일 인물: %s', similarity, string(isSamePerson)), ...
                 '❌ 동일 인물이 아니므로 가방 비교 생략'}, ...
                 'FontSize', 13, 'FontWeight', 'bold');
        return;
    end

    %===============================
    % Step 3: 가방 유무 분류 (확률 포함)
    %===============================
    inputSizeTrain = trainedNet.Layers(1).InputSize;
    imgBoardingTrain = imresize(imgBoarding_original, inputSizeTrain(1:2));
    imgExitingTrain  = imresize(imgExiting_original,  inputSizeTrain(1:2));

    [hasBag_boarding, scoreBoarding] = classify(trainedNet, imgBoardingTrain);
    [hasBag_exiting,  scoreExiting]  = classify(trainedNet, imgExitingTrain);

    confidence_boarding = max(scoreBoarding) * 100;
    confidence_exiting  = max(scoreExiting)  * 100;

    %===============================
    % Step 4: 결과 출력 및 시각화
    %===============================
    if isSamePerson && hasBag_boarding == "withbag" && hasBag_exiting == "withoutbag"
        decisionMsg = "[경고] 가방 분실 의심 상황입니다!";
    else
        decisionMsg = "이상 없음";
    end

    figure('Name', 'Classification & Similarity Result', 'NumberTitle', 'off');
    
    subplot(1,2,1);
    imshow(imgBoarding_original);
    title(sprintf('탑승 이미지\n%s', ...
        string(hasBag_boarding)));

    subplot(1,2,2);
    imshow(imgExiting_original);
    title(sprintf('하차 이미지\n%s', ...
        string(hasBag_exiting)));

    sgtitle({sprintf('📸 Cosine Similarity: %.4f → 동일 인물: %s', similarity, string(isSamePerson)), ...
             decisionMsg}, ...
             'FontSize', 13, 'FontWeight', 'bold');
end
