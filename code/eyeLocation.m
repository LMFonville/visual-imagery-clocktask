function [distance] = eyeLocation(w)
%% Setup eyes
% Short script to check distance from screen and if both eyes are clearly
% detectable using the eyetracker

whichScreen = max(Screen('Screens'));
white = WhiteIndex(whichScreen);
black = BlackIndex(whichScreen);
%[screenXpixels, screenYpixels] = Screen('WindowSize', w);
dispSize = Screen('Rect', w);
Screen('TextSize', w, 20);

% dotSize = 0.1*dispSize(4);
%dotSizePix = 30; % Dot size in pixels
dotSizePix = round(0.06*dispSize(4));
eyeColour = [255 0 0];

origin = [dispSize(3)/4 dispSize(4)/4];
size = [dispSize(3)/2 dispSize(4)/2];
[xCenter, yCenter] = RectCenter(dispSize); %make centre frame
penWidthPixels = 5;
baseRect = [0 0 size(1) size(2)];
frame = CenterRectOnPointd(baseRect, dispSize(3)/2, yCenter);

try
    tetio_startTracking();
    while ~KbCheck
        distance = [];
        [leftEye, rightEye, ~, ~] = tetio_readGazeData; % The last 2 vars are timestamp and trigSignal, currently unused so can replace with ~
        % The left & right eye columns follow [x y z] coordinates
        % The first 3 are user coordinate system, next 3 are track box coordinate system
        % For distance I need UCS z-axis
        if ~isempty(leftEye) || ~isempty(rightEye)
            leftEye = leftEye(end,:);
            rightEye = rightEye(end,:);
            leftEyeX = leftEye(end, 4)*size(1) + origin(1) ;
            leftEyeY = leftEye(end, 5)*size(2) + origin(2) ;
            rightEyeX = rightEye(end, 4)*size(1)+ origin(1);
            rightEyeY = rightEye(end, 5)*size(2)+ origin(2) ;
            %Change colour of the frame and the virtual eyes on screen
            %depending on the validity
            if leftEye(end, 13)==0 && rightEye(end,13)==0
                eyeColour = [0 255 0]; %green
                dotRects = [leftEyeX - dotSizePix/2, rightEyeX - dotSizePix/2;
                    leftEyeY - dotSizePix/2, rightEyeY - dotSizePix/2;
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
        DrawFormattedText(w, 'Press any key to continue if both eyes are visible and at the right distance from the screen.', 'center', dispSize(4) * 0.1, black);
        Screen('FrameRect', w, black, frame, penWidthPixels);
        if exist('dotRects', 'var')
            Screen('FillOval', w, eyeColour, dotRects, dotSizePix/2);
            Screen('FrameRect', w, eyeColour, frame, penWidthPixels);
            DrawFormattedText(w, sprintf('Current distance to the eye tracker: %.2f cm.',mean(distance)), 'center', dispSize(4) * 0.85, black);
        end
        Screen('Flip', w);
    end
    tetio_stopTracking();
catch
    tetio_stopTracking
    sca;
    disp('Something went wrong')
end
