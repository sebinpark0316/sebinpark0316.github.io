function letterbox_resize_batch_png_absolute()
    % 절대 경로 지정 (필요에 따라 직접 수정하세요)
    inputDir = 'C:\Users\ch082\OneDrive\바탕 화면\종설프3\ktx_recap';
    outputDir = 'C:\Users\ch082\OneDrive\바탕 화면\종설프3\ktx_raw';
    targetSize = [640 640];  % 출력 크기 설정

    % 출력 폴더가 없으면 생성
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % PNG 파일만 처리
    files = dir(fullfile(inputDir, '*.png'));

    for i = 1:length(files)
        filename = files(i).name;
        filepath = fullfile(inputDir, filename);
        img = imread(filepath);

        % Letterbox 방식 리사이즈
        imgResized = letterboxResize(img, targetSize);

        % 저장
        outputPath = fullfile(outputDir, filename);
        imwrite(imgResized, outputPath);

        fprintf('[%d/%d] Saved: %s\n', i, length(files), outputPath);
    end
end

function imgOut = letterboxResize(imgIn, targetSize)
    % 비율 유지 + 패딩 리사이즈 함수

    [h, w, ~] = size(imgIn);
    scale = min(targetSize ./ [h, w]);
    newSize = round([h, w] * scale);
    imgResized = imresize(imgIn, newSize);

    % 패딩 계산
    deltaH = targetSize(1) - newSize(1);
    deltaW = targetSize(2) - newSize(2);
    top = floor(deltaH / 2);
    bottom = ceil(deltaH / 2);
    left = floor(deltaW / 2);
    right = ceil(deltaW / 2);

    % 검정 패딩 추가
    imgOut = padarray(imgResized, [top, left], 0, 'pre');
    imgOut = padarray(imgOut, [bottom, right], 0, 'post');
end

letterbox_resize_batch_png_absolute