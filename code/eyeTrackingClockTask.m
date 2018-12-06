function [] = eyeTrackingClockTask(subID, session, eyeTracking)
%% Clear the workspace and the screen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sca;
close all;
%% Sort out some basics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
expFolder = uigetdir; %keep as is or you can change this to your folder
  % e.g. expFolder = 'path\to\experiment\';
% Set defaults in case no input is given, should not really be used though
if ~exist('subID','var');
    subID = 1;
end
% Session is either A or D and simply indicates which stimulus type is used first
% A for Analog clocks
% D for Digital clocks
if ~exist('session','var');
    session = 'A';
end
% Using eye-tracking is the default
if ~exist('eyeTracking', 'var');
    eyeTracking = 1;
else
    eyeTracking = 0;
end
%% Set up experiment paths and files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
playListFolder = [expFolder '\playlists\']; %Path to experiment
dataFolder = [expFolder '\data\']; %Path to output storage
if ~exist('dataFolder', 'dir');
  mkdir(dataFolder)
end
imgFolder = [expFolder '\stimuli\']; %Path to images used as stimuli
blockOrder = [playListFolder, 'selectBlock.csv'];
fileID = fopen(blockOrder);
tmp = textscan(fileID, '%s', 'Delimiter', ',');
nBlocks = length(tmp{1,1});
blockSelect = tmp{1,1}(2:nBlocks);
nBlocks = length(tmp{1,1})-1;
%Originally there were 12 possible combinations for playlists, we decided to cut it down to 6.
nBlocks = nBlocks/2;
blockRun = 1:(nBlocks);
fclose(fileID);
if session=='A'
    blockRun = fliplr(blockRun); %start with analog6
elseif session=='D'
    blockRun = blockRun; %for clarity, starts with digital1
else
    disp('Wrong session code used!')
    return
end
%% Connect to the eyetracker and setup files
if eyeTracking
    % This assumes the tobii SDK folder is in the experiment folder
    addpath(genpath('tobii-for-matlab'))
    % If it is not, use either uigetdir or specify full path
    % tobiiDir = uigetdir(pwd, 'Select the folder that contains the tobii SDK files');

    if ~exist('myEyetracker', 'var')
        tetio_init;
        myEyetracker = tetio_getTrackers;
        tetio_connectTracker(myEyetracker.ProductId);
    end
end
%% Set up screen for experiment
HideCursor;
whichScreen = max(Screen('Screens'));
white = WhiteIndex(whichScreen);
black = BlackIndex(whichScreen);
[w, rect] = Screen('Openwindow',whichScreen,white,[],[],2);
ifi=Screen('GetFlipInterval', w);
frame_rate = 1/ifi;
waitFrames = 1;
W=rect(RectRight); % screen width, easier to keep track of than rect(3)
H=rect(RectBottom); % screen height , easier to keep track of than rect(4)
Screen(w,'FillRect',white);
vbl = Screen('Flip', w); %initial timestamp used in calibration script
% Retrieve maximum priority number
topPriorityLevel = MaxPriority(w);
KbName('UnifyKeyNames');
KbQueueCreate;
%% Load first run playlist
expOutput = struct;
trialInput = [playListFolder char(blockSelect(blockRun(6)))];
fileID = fopen(trialInput);
% Column order:
% trialno trialcode stimFile trialDur timeElapsed
% trialOnset corrAns clockSource trialType questionTxt
tmp = textscan(fileID, '%s %s %q %s %s %s %s %q %q %q', 'Delimiter', ',');
runL = length(tmp{1,1});
for i = 1:(runL-1)
    expOutput.idx(i) = str2double(tmp{1,1}(i+1));
    expOutput.trialCode(i) = str2double(tmp{1,2}(i+1));
    expOutput.trialTime(i) = str2double(tmp{1,4}(i+1));
    expOutput.corrAns(i) = str2double(tmp{1,7}(i+1));
end
expOutput.stimFile = tmp{1,3}(2:runL);
expOutput.clockSource = tmp{1,8}(2:runL);
expOutput.trialType = tmp{1,9}(2:runL);
expOutput.questionType = tmp{1,10}(2:runL);
fclose(fileID);
nTrials = runL - 1;
%% Run setup to position participant and calibrate eye movements
expOutput.eyeTracking = eyeTracking;
if eyeTracking
    expOutput.distance = eyeLocation(w);
    expOutput.calibData = eyeCalibration(w, vbl);
    eyeGaze(w);
end
%% Load images used in run
fixCross = imread([imgFolder, 'fixCross.tiff']);
imgBox = imread([imgFolder, 'emptyImageryBox.tiff']);
imageSize = size(imgBox);
stimIdx = (expOutput.trialCode==1) + ...
    (expOutput.trialCode==4) + (expOutput.trialCode==5);
stimIdx = stimIdx==1;
stimList = expOutput.stimFile(stimIdx);
imgDisplay = zeros(1, length(expOutput.trialCode));
for i = 1:length(stimList)
    clockStim{i} = imread([imgFolder, stimList{i}]);
end
stimCount = 1;
for i = 1:nTrials
    if expOutput.trialCode(i) == 0
        imgDisplay(i) = Screen('MakeTexture', w, fixCross);
    elseif expOutput.trialCode(i) == 1 || expOutput.trialCode(i) == 4 || expOutput.trialCode(i) == 5
        imgDisplay(i) = Screen('MakeTexture', w, clockStim{stimCount});
        stimCount = stimCount+1;
    elseif expOutput.trialCode(i) == 3
        imgDisplay(i) = Screen('MakeTexture', w, imgBox);
    end
end
pos(1,:) = [(W-imageSize(2))/2 (H-imageSize(1))/2 ...
    (W+imageSize(2))/2 (H+imageSize(1))/2];
%% Instructions screen and prep exp params
Priority(topPriorityLevel);
instructions = imread([imgFolder, 'expInstructions.tiff']);
instructDisplay = Screen('MakeTexture', w, instructions);
Screen('DrawTexture', w, instructDisplay, [], pos(1,:));
vbl = Screen('Flip',w);
if eyeTracking
    tetio_startTracking;
    WaitSecs(0.5);
end
while 1
    [~,~,keyCode] = KbCheck;
    if keyCode(KbName('space'))==1
        break
    elseif keyCode(KbName('escape'))==1
        sca;
        return
    end
end
vbl = Screen('Flip', w, vbl + (waitFrames - 0.5) * ifi); %this is point zero for clock 1
startExp = vbl;
if eyeTracking
    tobiiStartExp = tetio_localTimeNow; %this is point zero for clock 2
    [~,~,gazeTimeStamp] = tetio_readGazeData;
    try
        gazeStartExp = gazeTimeStamp(end); %this is point zero for clock 3
    catch
        disp('No accurate eyegaze data.')
        gazeStartExp = NaN;
    end
    expClocks.startExp = [startExp, double(tobiiStartExp), double(gazeStartExp)];
else
    expClocks.startExp = startExp;
end
% There's 3 clocks in the experiment, I simply wanted to check accuracy since
% this is my first experiment using an eye-tracker. They basically all show
% similar timings and I stuck with the PTB one for my experiment.

%% Start Experiment Run
for runs = 1:nBlocks
    if eyeTracking
        expOutput.leftEye = {};
        expOutput.rightEye = {};
        expOutput.error = [];
    end
    %Loop through trials of the experiment
    for trials = 1:nTrials
        expClocks.trialPrep(trials,1) = GetSecs; %PTB time
        if eyeTracking
            eyePos = [];
            leftEyeX = [];
            leftEyeY = [];
            rightEyeX = [];
            rightEyeY = [];
            leftValid = [];
            rightValid = [];
            timeStamp = [];
            %timings
            expClocks.trialPrep(trials,2) = double(tetio_localTimeNow); %SDK time
            [~,~,gazeTimeStamp] = tetio_readGazeData;
            try
                expClocks.trialPrep(trials,3) = double(gazeTimeStamp(end)); %tobii time
            catch
                disp(['No accurate eyegaze data for start trial ' num2str(trials)])
                expClocks.trialPrep(trials,3) = NaN;
            end
        end
        lBoxColour = white;
        rBoxColour = white;
        %Load/prep stimulus
        if expOutput.trialCode(trials) == 4 || expOutput.trialCode(trials) == 5
            KbQueueStart;
            questionText = WrapString(expOutput.questionType{trials});
            Screen('TextSize',w, 45);
            DrawFormattedText(w, questionText,'center', H/10, 0, [], [], [], [], []);
            [~, ~, lBox] = DrawFormattedText(w, 'Yes', (W/2)-(imageSize(2)/1.5), H/2, 0, [], [], [], [], []); %nx, ny, textbounds not used
            [~, ~, rBox] = DrawFormattedText(w, 'No', (W/2)+(imageSize(2)/1.5), H/2, 0, [], [], [], [], []);
            Screen('FrameRect', w, lBoxColour, GrowRect(lBox, 7, 11)', 3);
            Screen('FrameRect', w, rBoxColour, GrowRect(rBox, 7, 11)',3);
            KbQueueFlush;
        end
        Screen('DrawTexture', w, imgDisplay(trials), [], pos(1,:));
        vbl = Screen('Flip',w, vbl + (waitFrames - 0.5) * ifi);
        expClocks.trialOnset(trials,1) = vbl;
        if eyeTracking
            expClocks.trialOnset(trials,2) = tetio_localTimeNow;
            [~,~,gazeTimeStamp] = tetio_readGazeData;
            try
                expClocks.trialOnset(trials,3) = gazeTimeStamp(end);
            catch
                disp(['No timestamp data for onset trial ' num2str(trials)]);
                expClocks.trialOnset(trials,3) = NaN;
            end
        end
        while GetSecs - expClocks.trialOnset(trials) < expOutput.trialTime(trials)
            if eyeTracking
                [leftEye, rightEye, gazeTimeStamp, ~] = tetio_readGazeData;
                try
                    eyePos = [eyePos; max(round(leftEye(end,3)/10,1),round(rightEye(end,3)/10,1))];
                    leftEyeX = [leftEyeX; leftEye(end,7)];
                    leftEyeY = [leftEyeY; leftEye(end,8)];
                    rightEyeX = [rightEyeX; rightEye(end,7)];
                    rightEyeY = [rightEyeY; rightEye(end,8)];
                    leftValid = [leftValid; leftEye(end, 13)];
                    rightValid = [rightValid; rightEye(end, 13)];
                    timeStamp = [timeStamp; gazeTimeStamp(end)];
                catch
                    expOutput.error = [expOutput.error;trials];
                end
            end
            if expOutput.trialCode(trials) > 3
                [pressed, firstPress] = KbQueueCheck;
                if pressed
                    firstPress(find(firstPress==0))=NaN; %Get rid of zeros?
                    [endTime, index] = min(firstPress);
                    theKeys=KbName(index);
                    if strcmp(theKeys, 'LeftArrow') == 1
                        lBoxColour = black;
                        keyResp = 1;
                    elseif strcmp(theKeys, 'RightArrow') == 1
                        rBoxColour = black;
                        keyResp = 2;
                    end
                    KbQueueStop;
                    DrawFormattedText(w, questionText,'center', H/10, 0, [], [], [], [], []);
                    [~, ~, lBox] = DrawFormattedText(w, 'Yes', (W/2)-(imageSize(2)/1.5), H/2, 0, [], [], [], [], []); %nx, ny, textbounds not used
                    [~, ~, rBox] = DrawFormattedText(w, 'No', (W/2)+(imageSize(2)/1.5), H/2, 0, [], [], [], [], []);
                    Screen('FrameRect', w, lBoxColour, GrowRect(lBox, 7, 11)', 3);
                    Screen('FrameRect', w, rBoxColour, GrowRect(rBox, 7, 11)',3);
                    Screen('DrawTexture', w, imgDisplay(trials), [], pos(1,:));
                    Screen('Flip',w, vbl + (waitFrames - 0.5) * ifi);
                    expOutput.RT(trials) = endTime - expClocks.trialOnset(trials,1);
                    expOutput.KeyResp(trials) = keyResp;
                end
            end
        end
        if eyeTracking
            expOutput.leftEye{trials} = [leftEyeX, leftEyeY];
            expOutput.rightEye{trials} = [rightEyeX, rightEyeY];
            expOutput.timeStamp{trials} = timeStamp;
            expOutput.eyePosition{trials} = eyePos;
            expOutput.validCode{trials} = [leftValid, rightValid];
            [~,~,gazeTimeStamp] = tetio_readGazeData;
            try
                gazeTrialDuration(trials) = gazeTimeStamp - gazeTrialOnset(trials);
                expClocks.trialEnd(trials, 3) = double(gazeTimeStamp(end));
            catch
                gazeTrialDuration(trials) = NaN;
                disp(['No gaze data for end of trial ' num2str(trials)])
            end
            expClocks.trialEnd(trials, 2) = double(tetio_localTimeNow);
        end
        expClocks.trialEnd(trials, 1) = GetSecs;
    end
    outputMat = [dataFolder num2str(subID) session '-outputRun_' num2str(runs) '.mat'];
    save(outputMat, 'expOutput', 'expClocks');
    %% Give participants the option of taking a short break
    Screen('TextSize',w, 36);
    if runs ~= nBlocks
        breakText = WrapString('There will now be a short break, please take a moment to relax. \n\nPress SPACE when you are ready to continue.');
        DrawFormattedText(w,breakText, 'center', 'center', [0 0 0], 0,0,0,1.5);
        vbl = Screen('Flip',w, vbl + (waitFrames - 0.5) * ifi);
        %Load next playlist
        expOutput = struct;
        trialInput = [playListFolder char(blockSelect(blockRun(runs+1)))];
        fileID = fopen(trialInput);
        %column order
        %trialno trialcode stimFile trialDur timeElapsed
        %trialOnset corrAns clockSource trialType questionTxt
        tmp = textscan(fileID, '%s %s %q %s %s %s %s %q %q %q', 'Delimiter', ',');
        runL = length(tmp{1,1});
        for i = 1:(runL-1)
            expOutput.idx(i) = str2double(tmp{1,1}(i+1));
            expOutput.trialCode(i) = str2double(tmp{1,2}(i+1));
            expOutput.trialTime(i) = str2double(tmp{1,4}(i+1));
            expOutput.corrAns(i) = str2double(tmp{1,7}(i+1));
        end
        expOutput.stimFile = tmp{1,3}(2:runL);
        expOutput.clockSource = tmp{1,8}(2:runL);
        expOutput.trialType = tmp{1,9}(2:runL);
        expOutput.questionType = tmp{1,10}(2:runL);
        fclose(fileID);
        nTrials = runL - 1;
        %Load images to buffer
        stimIdx = (expOutput.trialCode==1) + ...
            (expOutput.trialCode==4) + (expOutput.trialCode==5);
        stimIdx = stimIdx==1;
        stimList = expOutput.stimFile(stimIdx);
        imgDisplay = zeros(1, length(expOutput.trialCode));
        for i = 1:length(stimList)
            clockStim{i} = imread([imgFolder, stimList{i}]);
        end
        stimCount = 1;
        for i = 1:nTrials
            if expOutput.trialCode(i) == 0
                imgDisplay(i) = Screen('MakeTexture', w, fixCross);
            elseif expOutput.trialCode(i) == 1 || expOutput.trialCode(i) == 4 || expOutput.trialCode(i) == 5
                imgDisplay(i) = Screen('MakeTexture', w, clockStim{stimCount});
                stimCount = stimCount+1;
            elseif expOutput.trialCode(i) == 3
                imgDisplay(i) = Screen('MakeTexture', w, imgBox);
            end
        end
        while 1
            [~,~,keyCode] = KbCheck;
            if keyCode(KbName('space'))==1
                break
            elseif keyCode(KbName('escape'))==1
                sca;
                return
            end
        end
        vbl = Screen('Flip', w, vbl + (waitFrames - 0.5) * ifi);
    else
        endText = WrapString('The experiment has now finished, thank you for your participation.');
        DrawFormattedText(w,endText, 'center', 'center', [0 0 0], 0,0,0,1.5);
        vbl = Screen('Flip',w, vbl + (waitFrames - 0.5) * ifi);
        while 1
            [~,~,keyCode] = KbCheck;
            if keyCode(KbName('space'))==1
                break
            end
        end
    end
end
%% End the experiment and close the screen
if eyeTracking
    tetio_stopTracking;
    tetio_disconnectTracker;
end
sca;
