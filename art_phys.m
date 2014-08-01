%art_phys.m  written: 2013-03-22 by Ed Vessel (from rating_art.m)
%
%Collect ratings on a set of images.  1 Category
%
% Revision History:
%   2013-07-29  ev  added physio control
%   2013-03-22  ev  created from rating_art: change timing, add physio interactions
%   2012-01-31  ev  creating PC compatible version, LOCAL file!
%   2011-11-10  ev  added gamma table, split off version for architecture
%   2011-10-07  ev  copied from emg_pilot2
%   2011-01-07  ev  changed trialwise timekeeping to relative times
%   2011-01-05  ev  debugged to get a working version with image
%       presentation only
%   2010-12-20  ad  combined code from other scripts to make PTB3
%       compatible
%   2010-12-14  ev  began updating script for newer ver. PTB windows 3.0.8
%   2007-06-26  ev  previous revision date with old version




%----basic matlab housekeeping---------
clear all;
%ListenChar(2); %disable keyboard output to matlab window during script
timestamp.program_start = GetSecs;
rand('state',sum(100*clock));
%---------------------------------

%KEY PARAMETERS ---------------

expCode = 'aplab'; %art_physio, lab version


ssn= input('Subject number: ');
%stim_type = input('Stimulus type: ','s');
stim_type = 'art';
runnum = input('Run number: ');

min_pres_time = 5; %minimum viewing time before "next" option appears
max_pres_time = 20; %60; %maximum viewing time, at which change happens automatically
wait_time = 0; %time between stimulus presentation and response collection
it_time = 2; % 2000 ms - intertrial wait time
fix_time = 0.5; %500 ms

%'Next' prompt settings
next_prompt = 'NEXT -->';
nextOffset = [40 20]; %offset on the screen (x,y) from bottom right corner
prompt_fade_time = 1; %in seconds
%blinking prompt as max_pres_time approaches
to_grace_time = 10; %how long prompt blinks before timeout
blink_time = 1; %period (in s) for blinks

brk1 = 'n';
brktrial = 37; %take a break every X trials

SS.fractScreen = 0.9; %percentage of Screen image uses
SS.max_area = .75;  %max percentage of stimrect which a stimulus can occupy

%------------------------------

% set computer specific info
try
    hostname = mglGetHostName;
catch
    [retval hostname] = system('hostname');
    if retval ~=0,
        if ispc
            hostname = getenv('COMPUTERNAME');
        else
            hostname = getenv('HOSTNAME');
        end
    end
    hostname = lower(hostname);
    if (hostname(end) == char(10)) %strip off trailing return character
        hostname = hostname(1:(end-1))
    end
end
%hostname = 'Aiode.local';  %hostname not working from a firewalled router!!

switch hostname
    case 'rabi.cbi.fas.nyu.edu'
        disp('host set to Rabi')
        rootdir=('/Volumes/CBIUserData/starrlab/art_physio');
        newRes.width = 1680;
        newRes.height = 1050;
        newRes.hz = 60;
        newRes.pixelSize = 32;
    case 'Aiode.local'
        disp('host set to Aiode')
        rootdir=('/Volumes/CBIUserData/starrlab/art_physio');
        newRes.width = 1680;
        newRes.height = 1050;
        newRes.hz = 0;
        newRes.pixelSize = 32;
        setScreenNumber = 0;
        %load Phillips202p7_B0_C100_gamma.mat;
        load ViewsonicVE170_B50_C100_gamma.mat;
    case 'hockney'
        disp('host set to hockney')
        rootdir=('C:\Users\artlab\Documents\EXPERIMENTS\art_physio');
         newRes.width = 1280;
        newRes.height = 1024;
        newRes.hz = 60 ;
        newRes.pixelSize = 32;
        setScreenNumber = 0;
        ts = 18;
        tsp = ts*1.8;
        %load ViewsonicVE170_B50_C100_gamma.mat;
        %gammaTable = gammaTable*[1 1 1];
        load ViewsonicVE170_B50_C100_Win7Calib_Jun2013.mat; %NON linear table! set by OS
    otherwise
        disp('Screen & computer parameters set to default')
        %rootdir = pwd;  %set root to current directory
        rootdir = ('/Volumes/CBIUserData/starrlab/art_physio');
        newRes.width = 1280;
        newRes.height = 1024;
        newRes.hz = 75 ;
        newRes.pixelSize = 32;
        setScreenNumber = 1;
        ts = 35;
        tsp = ts;
        load Phillips202p7_B0_C100_gamma.mat;
end

physio = 0; %Set to 1 to send pulses to Processing via serial port

%codedir = ([rootdir,filesep,'code']);
%addpath(codedir);

homedir = ([rootdir,filesep,expCode]);
cd(homedir);
addpath(homedir);
imagedir = ([homedir,filesep,'Images']);
datadir = ([homedir,filesep,'Data']);
addpath(imagedir);
addpath(datadir);

so_ext = '.mat';

%PHYSIO serial port setup, for Processing/Camera/physio collection
if physio
    [s1,skey] = init_physio(0,ssn,runnum);
end

%get Subject information --------------------------------%

if isempty(ssn) ssn=0; end
if (ssn==0)
    %imagedir = ([homedir,filesep,'practice_images']);
    %path(path,imagedir);
else
    name= input('Subject Initials: ','s');
    gend=input('Gender (m/f): ','s');
    hand=input('Handedness (l/r): ','s');
    age=input('Age: ');
end


%is = 'y';
%is=input('Show instructions? (Y/n): ','s');
is = 'n';
instrskip = 1;
if (is == 'n')
    instrskip = 0;
else
    numprac = 0;
    np = input(['Number of Practice Trials [',int2str(numprac),']: ']);
    if (np); numprac = np; end
end;
%------------------------------------------------------%



%load stimulus order -----------------------------------%
if (ssn==0)
    so{1} = [1:10]';
else
    ordertext = [expCode,'_',stim_type,'_',int2str(ssn),so_ext];
    so = load(ordertext);
end

% if runnum ==2
%     so = flipdim(so,1);
% end

%set up retest block
n_blocks = length(so);
for block = 1:n_blocks
    n_trials(block) = length(so{block});
end 

%d = dir([imagedir,filesep,'*.jpg']);
d = dir([imagedir,filesep,'*.tif']);

[n_stim junk] = size(d);

if (n_stim ~= max(union(so{:})))
    disp('Stimulus order contains incorrect number of stimuli!');
    %break;
end


FlushEvents('keydown');
%------------------------------------------------------%


%SET UP Screens and some stimulus parameters-----------%
%set Screen:
%on experimental computer: use 0
if exist('setScreenNumber')
    SS.ScreenNumber=setScreenNumber;
else
    SS.ScreenNumber=1;
end

%set up preferences, pixel depth, etc.
oldRes = Screen('Resolution',SS.ScreenNumber,newRes.width,newRes.height,newRes.hz,newRes.pixelSize);

%colors
white=WhiteIndex(SS.ScreenNumber);
black=BlackIndex(SS.ScreenNumber);
gray = 120;
bgcolor = [gray gray gray];
%bgcolor = [white white white];
textcolor = [black black black];
%text_bgcolor = [200 200 200];
text_bgcolor = bgcolor;

%set up trial timing parameters - code times in absolute time, not
%refreshes
RefreshRate = Screen('FrameRate',SS.ScreenNumber); %measure Refresh Rate

% set up fixation point
fixsize=15;
fixcross = ones(fixsize,fixsize,3)*bgcolor(1);
fixcross(ceil(fixsize/2):ceil(fixsize/2),1:fixsize,:) = black;
fixcross(1:fixsize,ceil(fixsize/2):ceil(fixsize/2),:) = black;

text_border = [50 150];

%Set up keys
KbName('UnifyKeyNames');
keydefs.next = KbName('RightArrow');
keydefs.esckey = KbName('ESCAPE');




%------------------------------------------------------%


try
    % Making sure we're dealing with the newer version of PTB:
    AssertOpenGL;
    HideCursor;
    
    [wholeScreen, SS.ScreenRect] = Screen('OpenWindow', SS.ScreenNumber, bgcolor);
    
    %Load normalized gamma table
    old_gt = Screen('LoadNormalizedGammaTable', SS.ScreenNumber, gammaTable);
    
    % Getting inter-flip interval (ifi), (i.e., the refresh rate, how long
    % it takes the computer to put up a new Screen).
    Priority(MaxPriority(wholeScreen));
    SS.ifi = Screen('GetFlipInterval', wholeScreen);
    Priority(0);
    
    %%% Storing generally useful Screen value variables in the SS struct array:
    
    SS.x_min = SS.ScreenRect(1);
    SS.x_max = SS.ScreenRect(3);
    SS.y_min = SS.ScreenRect(2);
    SS.y_max = SS.ScreenRect(4);
    
    SS.AspectRatio = SS.x_max/SS.y_max;
    SS.winWidth = SS.x_max-SS.x_min;
    SS.winHeight = SS.y_max-SS.y_min;
    SS.x_center = SS.winWidth/2;
    SS.y_center = SS.winHeight/2;
    
    %set up windows and rect's for stimulus, text, & fixation point
    SS.FixRect = [0 0 fixsize fixsize];
    SS.Fixation = CenterRect(SS.FixRect, SS.ScreenRect);
    fixTex = Screen('MakeTexture',wholeScreen,fixcross);
    
    Screen('TextFont', wholeScreen, 'Arial');
    textsize = [0 0 400 120];
    SS.textrect =CenterRect([textsize]+ [0 0 text_border(1) text_border(2)],SS.ScreenRect);
    %[textwin, SS.TextwinRect] = Screen('OpenWindow',SS.ScreenNumber,bgcolor,textrect);
    Screen('Preference', 'TextAlphaBlending', 1);
    Screen('BlendFunction',wholeScreen,GL_ONE,GL_ZERO);
    oldTextBackgroundColor=Screen('TextBackgroundColor', wholeScreen,text_bgcolor);

    SS.stimsize = SS.ScreenRect([1 1 4 4]) .* (SS.fractScreen);
    
    %"Next" prompt
    %FIX THIS 
    SS.nextsize= Screen('TextBounds', wholeScreen, next_prompt);
    SS.nextrect = [(SS.x_max - SS.nextsize(3)) (SS.y_max - SS.nextsize(4)) SS.x_max SS.y_max] - [nextOffset(1) nextOffset(2) nextOffset(1) nextOffset(2)]; 
    SS.next_steps = floor(prompt_fade_time ./ SS.ifi);
    
    %run instructions
    if (instrskip == 1) done = art_phys_instr(homedir,numprac, black,bgcolor,textcolor,ts,tsp,wholeScreen,SS,fixcross,min_pres_time,fix_time,it_time,wait_time); end
    
    %LOAD STIMULI
    Screen('TextFont', wholeScreen, 'Arial');
    Screen('TextSize',wholeScreen,ts);
    
    [imglist{1:n_stim}] = deal(d.name);
    for i = 1:n_stim
        imgname = imglist{i};
        if size(find(union(so{:}) == i),1) %only load those images we are actually going to use
            testimg = imread([imagedir,filesep,imgname]);
            imgsz(i,:) = size(testimg); %width, height, colorchannels
            imgratio(i) = imgsz(i,1) / imgsz(i,2); %ratio of width/height
            if imgsz(i,1) > SS.stimsize(3) % if image width is bigger than stimrect width
                imgsz(i,1) = SS.stimsize(3);
                imgsz(i,2) = imgsz(i,1)./imgratio(i);
            end
            if imgsz(i,2) > SS.stimsize(4)
                imgsz(i,2) = SS.stimsize(4);
                imgsz(i,1) = imgsz(i,2).*imgratio(i);
            end
            img_area(i) = imgsz(i,1) .* imgsz(i,2);
            if ( img_area(i) > (SS.max_area.*SS.stimsize(3).*SS.stimsize(4)) ) %scale max area
               side_rescale = sqrt((SS.max_area.*SS.stimsize(3).*SS.stimsize(4)) ./ img_area(i));
               imgsz(i,1) = imgsz(i,1) .* side_rescale;
               imgsz(i,2) = imgsz(i,2) .* side_rescale;
            end
            imTex(i) = Screen('MakeTexture',wholeScreen , testimg);
            
        end
        
        %display progress
          Screen('Drawtext',wholeScreen,['Loading Images: ',int2str(round((i/n_stim)*100)),'%'],SS.textrect(1),SS.textrect(2),textcolor,text_bgcolor);
          Screen('Flip', wholeScreen);  %show text
  
        
    end
    sound(sin([1:500])); %beep when done
    
    Screen('Flip',wholeScreen);  %clear text
    
    Screen('Drawtext',wholeScreen,'Hit any key to start',SS.textrect(1),SS.textrect(2),textcolor,text_bgcolor);
    Screen('Flip', wholeScreen);  %show text
    KbWait;
    Screen('Flip',wholeScreen);
    
    pause(1);
    escape = 0;
    
    timestamp.experiment_start = GetSecs;


    for block = 1:n_blocks    
        
        %need to initialize data
        data{block}.time = 0;
        data{block}.resp = 0;
        
        %wait for backtick (fmri)
        
        timestamp.block_start(block) = GetSecs;
        if physio;fprintf(s1,skey.start); end %START physio data collection
        
        for trial = 1:n_trials  %TRIAL LOOP
            
            data{block}.trialstart(trial) = GetSecs -  timestamp.experiment_start;
            
            %fixation
            Screen('DrawTexture',wholeScreen,fixTex,[],SS.Fixation);
            Screen('Flip',wholeScreen);
            %draw stimulus in back buffer
            stimrect = CenterRect([0 0 imgsz(so{block}(trial),2) imgsz(so{block}(trial),1)],SS.ScreenRect);
            Screen('DrawTexture',wholeScreen,imTex(so{block}(trial)),[],stimrect);
            
            %SHOW IMAGE: wait until "trial start" time & flip buffer
            Screen('Flip',wholeScreen,timestamp.experiment_start + data{block}.trialstart(trial) + fix_time);
            %start recording physio data, or send 'event' messages to
            %recording systems indicating beginning of trial, etc.
            %STIM ON - physio
            if physio; fprintf(s1,skey.trial); end
            
            done = 0;
            
            %wait for min_pres_time, then fade in "next" prompt
            Screen('DrawTexture',wholeScreen,imTex(so{block}(trial)),[],stimrect);
            prompt_color = text_bgcolor;
            Screen('DrawText',wholeScreen,next_prompt,SS.nextrect(1),SS.nextrect(2),prompt_color,text_bgcolor);
            Screen('Flip',wholeScreen,timestamp.experiment_start + data{block}.trialstart(trial) + fix_time + min_pres_time - prompt_fade_time);
            for nn = 1:SS.next_steps
            Screen('DrawTexture',wholeScreen,imTex(so{block}(trial)),[],stimrect);
            prompt_color = text_bgcolor + ((textcolor - text_bgcolor) .* (nn/SS.next_steps));
            Screen('DrawText',wholeScreen,next_prompt,SS.nextrect(1),SS.nextrect(2),prompt_color,text_bgcolor);
            Screen('Flip',wholeScreen);
               
            end
            while(~done) %image ON loop             
 
                %monitor for keypress
                FlushEvents('keydown');
                [keyIsDown,tim,keyCode]=KbCheck(-1);
                if (size(find(keyCode),2)==1);
                    respkey = (find(keyCode));
                    switch respkey
                        case keydefs.next
                            resp = 1;
                            done = 1;
                            if physio; fprintf(s1,skey.next); end %PHYSIO: send 'next' key to physio
                        case keydefs.esckey
                            escape=1;
                            done = 1;
                    end
                end;
                
                %Poll time, when max_pres_time (TIMEOUT) is reached, blink "next" prompt
                cur_time = (GetSecs - (timestamp.experiment_start + data{block}.trialstart(trial)));
                if (cur_time >= (fix_time + max_pres_time ))
                    done = 1;
                elseif (cur_time >= (fix_time + max_pres_time - to_grace_time))
                    %start blinking image
                    if (rem((cur_time - (fix_time + max_pres_time - to_grace_time)),blink_time) < blink_time/2)
                        to_prompt_color = text_bgcolor;
                    else
                        to_prompt_color = textcolor;
                    end
                    %draw
                    Screen('DrawTexture',wholeScreen,imTex(so{block}(trial)),[],stimrect);
                    Screen('DrawText',wholeScreen,next_prompt,SS.nextrect(1),SS.nextrect(2),to_prompt_color,text_bgcolor);
                    Screen('Flip',wholeScreen);
                end
                
            end %END image ON loop
            %REMOVE IMAGE: wait & clear
            Screen('Flip',wholeScreen);
            %Screen('Flip',wholeScreen,timestamp.experiment_start +  data{block}.trialstart(trial) + fix_time + min_pres_time);
            
            if escape; break;end;
            
            %data to collect: how long subject looked before hitting "continue/next", + physio
            %measures
            %data{block}.time(trial) = (tim - st);
            %data{block}.resp(trial) = find(resplist);
            
            %end of stimulus and response--------------------%      
            
            %intertrial interval
            while (GetSecs < (tim + it_time)); end   
            
            if and(brk1=='y', (mod(trial,brktrial) == 0));
                Screen('DrawText',wholeScreen,'Take a short break',SS.textrect(1),SS.textrect(2),textcolor,text_bgcolor);
                Screen('DrawText',wholeScreen,'Hit a key to continue',SS.textrect(1),SS.textrect(2)+tsp,textcolor,text_bgcolor);
                Screen('Flip',wholeScreen);
                KbWait([],3);
                Screen('Flip',wholeScreen);
                pause(1);
            end;
            
            FlushEvents('keydown');
            
            
        end %END trial loop
        
        %send physio END data collection
        timestamp.block_end(block) = GetSecs;
        if physio; fprintf(s1,skey.end); end;
        
        if escape; break; end
        
            if (block < n_blocks)
                Screen('DrawText',wholeScreen,'Take a short break',SS.textrect(1),SS.textrect(2),textcolor,text_bgcolor);
                Screen('DrawText',wholeScreen,'Hit a key to continue',SS.textrect(1),SS.textrect(2)+tsp,textcolor,text_bgcolor);
                Screen('Flip',wholeScreen);
                KbWait([],3);
                Screen('Flip',wholeScreen);
                pause(1);
            end
        
    end %END block loop
        
        timestamp.program_end = GetSecs;
        timestamp.exptime = timestamp.program_end - timestamp.experiment_start;
        
        
        %CLEAN UP
        %close windows & return pixel depth
        ShowCursor;
        Screen('CloseAll');
        Screen('Resolution',SS.ScreenNumber,oldRes.width,oldRes.height,oldRes.hz,oldRes.pixelSize);
        Screen('LoadNormalizedGammaTable',SS.ScreenNumber,old_gt);
        ListenChar(0);
        if physio; fclose(s1); end
        
        catch % Cleanup if something goes wrong above.
            sprintf('Error: %s', lasterr)
            Priority(0);
            ShowCursor
            Screen('CloseAll');
            Screen('Resolution',SS.ScreenNumber,oldRes.width,oldRes.height,oldRes.hz,oldRes.pixelSize);
            Screen('LoadNormalizedGammaTable',SS.ScreenNumber,old_gt);
            ListenChar(0);
            if physio; fclose(s1); end
            
            save DebugVars;
            error_struct = lasterror;
            error_output = [];
            for i = 1:length(error_struct.stack)
                error_lines = error_struct.stack(i);
                error_output = [error_output, sprintf('file: %s\t\t\tline: %d\n',error_lines.name, error_lines.line)];
            end
            disp(error_output)
            rethrow(lasterror)
    end
    
    %write out data
    
    %write text to summary file for each block
    %ssn block name gend hand age
    %trials,n_stim,heapnum
    if ssn~=0;
        sumfile = [datadir,filesep,expCode,'_',stim_type,'_summary.dat'];
        sfid = fopen(sumfile,'at');
        fprintf(sfid,'\n%d\t%d\t%s\t%d\t%4.1f\t%s\t%s\t%s\t%d\n',ssn, runnum, date, n_stim, timestamp.exptime, name, gend, hand, age);
        %save .mat file of main data sets
        %sl, sc, M, data, n_comp
        save([datadir,filesep,int2str(ssn),'_',expCode,'_',stim_type,'_r',int2str(runnum),'.dat'],'so','data','-mat');
    end
    
    disp(['Total time: ',num2str(timestamp.exptime,4),' seconds']);
    
    fclose('all');
