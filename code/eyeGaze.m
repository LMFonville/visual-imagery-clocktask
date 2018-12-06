function [] = eyeGaze(w)
%% Housekeeping
HideCursor;
whichScreen = max(Screen('Screens'));
white = WhiteIndex(whichScreen);
black = BlackIndex(whichScreen);
dispSize = Screen('Rect', w);
[screenXpixels, screenYpixels] = Screen('WindowSize', w);
dotSizePix = round(0.06*dispSize(4));
eyeColour = [255 0 0];

calibPoints = [[0.2, 0.8, 0.5, 0.8, 0.2]*dispSize(3);
    [0.2, 0.2, 0.5, 0.8, 0.8]*dispSize(4)];

%% Check live eyegaze data quality
DrawFormattedText(w, 'Press any key to continue.', 'center', screenYpixels * 0.1, black);
%Screen('FrameRect', w, black, frame, penWidthPixels);
Screen('DrawDots', w, calibPoints, 20, [255 0 0]);
Screen('Flip', w);
tetio_startTracking();
WaitSecs(0.5);
while ~KbCheck
    distance = [];
    [leftEye, rightEye, ~, ~] = tetio_readGazeData; %last 2 vars are timestamp and trigSignal, currently unused so can replace with ~
    % The left & right eye columns follow [x y z] coordinates
    % The first 3 are user coordinate system, next 3 are track box coordinate system
    % For distance I need UCS z-axis
    if ~isempty(leftEye) || ~isempty(rightEye)
        leftEye = leftEye(end,:);
        rightEye = rightEye(end,:);
        leftEyeX = leftEye(end, 7) *dispSize(3);
        leftEyeY = leftEye(end, 8)*dispSize(4 ) ;
        rightEyeX = rightEye(end, 7)*dispSize(3);
        rightEyeY = rightEye(end, 8)*dispSize(4 ) ;
        % Change colour of the eyes on screen depending on the validity
        if leftEye(end, 13)==0 && rightEye(end,13)==0
            eyeColour = [0 255 0]; %green
            dotRects = [leftEyeX - dotSizePix/2, rightEyeX - dotSizePix/2;
                leftEyeY - dotSizePix/2 , rightEyeY - dotSizePix/2;
                leftEyeX  + dotSizePix/2, rightEyeX + dotSizePix/2;
                leftEyeY + dotSizePix/2, rightEyeY + dotSizePix/2];
        elseif leftEye(end, 13)==0 && rightEye(end, 13) ~= 0
            eyeColour = [255 255 0];  %yellow
            dotRects = [leftEyeX - dotSizePix/2;
                leftEyeY - dotSizePix/2;
                leftEyeX  + dotSizePix/2;
                leftEyeY + dotSizePix/2];
        elseif leftEye(end,13) ~= 0 && rightEye(end,13) == 0
            eyeColour = [255 255 0];%yellow
            dotRects = [rightEyeX - dotSizePix/2;
                rightEyeY - dotSizePix/2;
                rightEyeX + dotSizePix/2;
                rightEyeY + dotSizePix/2];
        elseif leftEye(end,13) ~= 0 && rightEye(end,13) ~= 0
            eyeColour = [255 0  0]; %red
        end
        distance = [distance; max(round(leftEye(end,3)/10,1),round(rightEye(end,3)/10,1))];
    end
    DrawFormattedText(w, 'Press any key if this works.', 'center', screenYpixels * 0.1, black);
    if exist('dotRects', 'var')
        Screen('FillOval', w, eyeColour, dotRects, round(dotSizePix/10) );
        DrawFormattedText(w, sprintf('Current distance to the eye tracker: %.2f cm.',mean(distance)), 'center', screenYpixels * 0.85, black);
    end
    Screen('DrawDots', w, calibPoints, 20, [255 0 0]);
    Screen('Flip', w);
end
tetio_stopTracking();
