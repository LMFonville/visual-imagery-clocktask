function [] = practiceClockTask(subID)
%% Clear the workspace and the screen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sca;
close all;
%% Sort out some basics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
expFolder = 'C:\Users\eye-tracker\Documents\Leon Experiments\clockTask';
%Set defaults in case no input is given, should not really be used though
if exist('subID','var') == 0;
    subID = 1;
end
%% Set up experiment paths and files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
bhvrFolder = [expFolder '\Behavioural\']; %Path to experiment
imgFolder = [expFolder '\stimuli\']; %Path to images used as stimuli
dataFolder = [bhvrFolder '\data\'];
trialInput = [bhvrFolder 'practiceSet.csv'];
fileID = fopen(trialInput);
%trialno trialcode stimFile trialDur timeElapsed trialOnset corrAns
%clockSource trialType questionTxt
tmp = textscan(fileID, '%s %s %q %s %s %s %s %q %q %q', 'Delimiter', ',');
runL = length(tmp{1,1});
for i = 1:(runL-1)
    expOutput.idx(i) = str2double(tmp{1,1}(i+1));
    expOutput.trialCode(i) = str2double(tmp{1,2}(i+1));
    expOutput.trialDuration(i) = str2double(tmp{1,4}(i+1));
    expOutput.corrAns(i) = str2double(tmp{1,7}(i+1));
end
expOutput.stimFile = tmp{1,3}(2:runL);
expOutput.clockSource = tmp{1,8}(2:runL);
expOutput.trialType = tmp{1,9}(2:runL);
expOutput.questionType = tmp{1,10}(2:runL);
fclose(fileID);
nTrials = runL - 1;
%% Set up screen for experiment
HideCursor;
whichScreen = max(Screen('Screens'));
white = WhiteIndex(whichScreen);
black = BlackIndex(whichScreen);
oldfontName = Screen('Preference', 'DefaultFontName', 'Sans');
[w, rect] = Screen('Openwindow',whichScreen,white,[],[],2);
%[w, rect] = Screen('Openwindow',1,white,[],[],2); %temporary to deal with multi-screens
ifi=Screen('GetFlipInterval', w);
frame_rate = 1/ifi;
W=rect(RectRight); % screen width
H=rect(RectBottom); % screen height
Screen(w,'FillRect',white);
Screen('Flip', w); %temporary
%Screen('Close', w); %when I just need to check the screen details
% Retrieve maximum priority number
topPriorityLevel = MaxPriority(w);
waitframes = 1;
KbName('UnifyKeyNames');
KbQueueCreate;
%% Instructions screen and prep exp params
fixCross = imread([imgFolder, 'fixCross.tiff']);
imgBox = imread([imgFolder, 'emptyImageryBox.tiff']);
imageSize = size(imgBox);
pos(1,:) = [(W-imageSize(2))/2 (H-imageSize(1))/2 ...
    (W+imageSize(2))/2 (H+imageSize(1))/2];
Priority(topPriorityLevel);
% Start screen
instructions = imread([imgFolder, 'expInstructions.tiff']);
imageDisplay = Screen('MakeTexture', w, instructions);
Screen('DrawTexture', w, imageDisplay, [], pos(1,:));
Screen('Flip',w);
while 1
    [~,~,keyCode] = KbCheck;
    if keyCode(KbName('space'))==1
        break
    elseif keyCode(KbName('escape'))==1
        return
    end
end
startExp = Screen('Flip', w); %this is point zero for clock 1
%% Start Experiment Run
for trials = 1:nTrials
    lBoxColour = white;
    rBoxColour = white;
    trialStart(trials) = GetSecs;
    if expOutput.trialCode(trials) == 0
        img = fixCross;
        imageDisplay = Screen('MakeTexture', w, img);
    elseif expOutput.trialCode(trials) == 1
        img = imread([imgFolder, expOutput.stimFile{trials}]);
        imageDisplay = Screen('MakeTexture', w, img);
    elseif expOutput.trialCode(trials) == 3
        img = imgBox;
        imageDisplay = Screen('MakeTexture', w, img);
    elseif expOutput.trialCode(trials) == 4 || expOutput.trialCode(trials) == 5
        KbQueueStart;
        breakText = WrapString(expOutput.questionType{trials});
        img = imread([imgFolder, expOutput.stimFile{trials}]);
        imageDisplay = Screen('MakeTexture', w, img);
        KbQueueFlush;
    end
    prepTime(trials) = GetSecs - trialStart(trials);
    trialOnset(trials) = GetSecs - startExp;
    if expOutput.trialCode(trials) < 3
        while GetSecs - (trialOnset(trials)+startExp) < expOutput.trialDuration(trials)
            Screen('DrawTexture', w, imageDisplay, [], pos(1,:));
            Screen('Flip',w);
        end
    elseif expOutput.trialCode(trials) == 3
        while GetSecs - (trialOnset(trials)+startExp) < expOutput.trialDuration(trials)
            Screen('DrawTexture', w, imageDisplay, [], pos(1,:));
            Screen('Flip',w);
        end
    elseif expOutput.trialCode(trials) > 3
        while GetSecs - (trialOnset(trials)+startExp) < expOutput.trialDuration(trials)
            Screen('TextSize',w, 45);
            Screen('DrawTexture', w, imageDisplay, [], pos(1,:));
            DrawFormattedText(w, breakText,'center', H/10, 0, [], [], [], [], []);
            [~, ~, ~, lBox] = DrawFormattedText(w, 'Yes', (W/2)-(imageSize(2)/1.5) , H/2, 0, [], [], [], [], []);
            [~, ~, ~, rBox] = DrawFormattedText(w, 'No', (W/2)-(imageSize(2)/1.5), H/2, 0, [], [], [], [], []);
            Screen('FrameRect', w, lBoxColour, GrowRect(lBox, 7, 11)', 3);
            Screen('FrameRect', w, rBoxColour, GrowRect(rBox, 7, 11)',3);
            [pressed, firstPress] = KbQueueCheck;
            if pressed
                firstPress(find(firstPress==0))=NaN; %Get rid of zeros?
                [endTime index] = min(firstPress);
                theKeys=KbName(index);
                if strcmp(theKeys, 'LeftArrow') == 1
                    lBoxColour = black;
                    keyResp = 1;
                elseif strcmp(theKeys, 'RightArrow') == 1
                    rBoxColour = black;
                    keyResp = 2;
                end
                KbQueueStop;
                expOutput.RT(trials) = endTime - (trialOnset(trials)+startExp);
                expOutput.KeyResp(trials) = keyResp;
            end
            Screen('Flip',w);
        end
    end
    actualTrialDuration(trials) = GetSecs - trialStart(trials) + prepTime(trials);
%     tobiiTrialDuration(trials) = tetio_localTimeNow - tobiiTrialOnset(trials);
end
outputMat = [dataFolder num2str(subID) '-outputPractice.mat'];
save(outputMat, 'expOutput');
%% End the experiment and close the screen
endText = WrapString('This is the end of the practice session. ');
DrawFormattedText(w,endText, 'center', 'center', [0 0 0], 0,0,0,1.5);
Screen('Flip',w);
while 1
    [~,~,keyCode] = KbCheck;
    if keyCode(KbName('space'))==1
        break
    end
end
vbl = Screen('Flip', w);
endExp = vbl;
sca;
