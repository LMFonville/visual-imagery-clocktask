function [calibPlotData] = eyeCalibration(w, vbl)
% This is mostly based on Jan Freyberg's code from his PsychTobiiCalibrate.m script.

whichScreen = max(Screen('Screens'));
white = WhiteIndex(whichScreen);
black = BlackIndex(whichScreen);
dispSize = Screen('Rect', w);
waitframes = 1;
ifi=Screen('GetFlipInterval', w);

%% Set up 5 points on the screen to use for calibration
% %(0.1, 0.1) left top boundary
% %(0.9, 0.1) right top boundary
% %(0.5, 0.5) center
% %(0.9, 0.9) right bottom boundary
% %(0.1, 0.9) left bottom boundary
% Slight deviation from those since our FOI is not the whole screen
calibPoints = [[0.2, 0.8, 0.5, 0.8, 0.2]*dispSize(3);
    [0.2, 0.2, 0.5, 0.8, 0.8]*dispSize(4)];
calibOrder = randperm(5);
calibPoints = [calibPoints(1, calibOrder); calibPoints(2, calibOrder)];
%% Start calibration
tetio_startCalib;
while 1
    WaitSecs(0.1);
    dotSize = round([linspace(0.05*min(dispSize(3:4)), 0.015*min(dispSize(3:4)), 30), 0.015*min(dispSize(3:4)) - 0.005*min(dispSize(3:4))*sin(linspace(0, 4*pi, 45))]);
    dotColor = [255 0 0]; %red
    smallDot = 0.002*min(dispSize(3:4));

    % Loop through the calibration points
    for i = 1:length(calibOrder) % move dots
        if i>1
            speed = round(60 * ( sqrt( (calibPoints(1, i-1)-calibPoints(1, i))^2 +  (calibPoints(2, i-1)-calibPoints(2, i))^2)/(0.4*dispSize(4)) ));
            movePoint = [linspace(calibPoints(1, i-1), calibPoints(1, i), speed); linspace(calibPoints(2, i-1), calibPoints(2, i), speed)];
        else
            speed = round(60 * ( sqrt( (calibPoints(1, 5)-calibPoints(1, 1))^2 +  (calibPoints(2, 5)-calibPoints(2, 1))^2)/(0.4*dispSize(4))));
            movePoint = [linspace(calibPoints(1, 5), calibPoints(1, 1), speed); linspace(calibPoints(2, 5), calibPoints(2, 1), speed)];
        end
        for ii = 1:speed
            Screen('FillOval', w, dotColor, [movePoint(1, ii)-dotSize(1)/2, movePoint(2, ii)-dotSize(1)/2, movePoint(1, ii)+dotSize(1)/2, movePoint(2, ii)+dotSize(1)/2]);
            Screen('FillOval', w, black, [movePoint(1, ii)-smallDot, movePoint(2, ii)-smallDot, movePoint(1, ii)+smallDot, movePoint(2, ii)+smallDot]);
            vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
        end

        WaitSecs(0.3);

        for ii = 1:75 % shrink dots
            Screen('FillOval', w, dotColor, [calibPoints(1, i)-dotSize(ii)/2, calibPoints(2, i)-dotSize(ii)/2, calibPoints(1, i)+dotSize(ii)/2, calibPoints(2, i)+dotSize(ii)/2]);
            Screen('FillOval', w, black, [calibPoints(1, i)-smallDot, calibPoints(2, i)-smallDot, calibPoints(1, i)+smallDot, calibPoints(2, i)+smallDot]);
            vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
        end
        tic;
        tetio_addCalibPoint(calibPoints(1, i)/dispSize(3), calibPoints(2, i)/dispSize(4));
        toc;
        pause(0.2);
        WaitSecs(0.5);
    end
    %% Compute, Redo calibration?
    tetio_computeCalib;
    calibPlotData = tetio_getCalibPlotData;
    % Arrange data by column for easy storage
    % 1,2 = x,y calibration points
    % 3-5 = Left eye xy points and validation
    % 6-8 = Right eye xy points and validation
    calibPlotData = reshape(calibPlotData, 8, [])';
    %WaitSecs(0.5);
    calibPlotData(:, [1,3,6]) = calibPlotData(:, [1,3,6]) * dispSize(3);
    calibPlotData(:, [2,4,7]) = calibPlotData(:, [2,4,7]) * dispSize(4);

    %Plot the calibration points and deviations
    leftEye = calibPlotData(:, 1:5);
    leftEye = leftEye(leftEye(:,5)==1,:); %removes all rows where column 5 (validity) is not 1
    rightEye = calibPlotData(:, [1,2,6:8]);
    rightEye = rightEye(rightEye(:,5)==1,:); %removes all rows where column 8 (validity) is not 1

    leftEyeLines = zeros(2, 2*size(leftEye,1));
    leftEyeLines(1, 1:2:2*size(leftEye,1)) = leftEye(:,3)';
    leftEyeLines(2, 1:2:2*size(leftEye,1)) = leftEye(:,4)';
    leftEyeLines(1, 2:2:2*size(leftEye,1)) = leftEye(:,1)';
    leftEyeLines(2, 2:2:2*size(leftEye,1)) = leftEye(:,2)';

    rightEyeLines = zeros(2, 2*size(rightEye,1));
    rightEyeLines(1, 1:2:2*size(rightEye,1)) = rightEye(:,3)';
    rightEyeLines(2, 1:2:2*size(rightEye,1)) = rightEye(:,4)';
    rightEyeLines(1, 2:2:2*size(rightEye,1)) = rightEye(:,1)';
    rightEyeLines(2, 2:2:2*size(rightEye,1)) = rightEye(:,2)';

    %Draw results from calibration
    Screen('DrawLines', w, leftEyeLines,2,[255 0 0]) %red
    Screen('DrawLines', w, rightEyeLines,2,[0 255 0]) %green
    Screen('DrawDots', w, calibPoints, 10, [0 0 0], [], 2);
    Screen('DrawDots', w, [leftEye(:,3), leftEye(:,4)]', 4, [255 0 0], [], 2);
    Screen('DrawDots', w, [rightEye(:,3), rightEye(:,4)]', 4, [0 255 0], [], 2);
    DrawFormattedText(w, 'Press ENTER if calibration looks fine or press SPACE to recalibrate.', 'center', 0.25*dispSize(4));
    Screen('Flip', w);

    WaitSecs(2);
    [~, keyCode, ~] = KbWait;
    if keyCode(KbName('return'))
        break
    elseif keyCode(KbName('space'))
        tetio_clearCalib;
        continue
    else
        error('Interrupted during Tobii Calibration');
    end

end
tetio_stopCalib;
