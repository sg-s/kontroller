% Kontroller.m
% Kontroller is at http://github.com/sg-s/kontroller/
% 
% created by Srinivas Gorur-Shandilya. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
%
% === 1. Basic Use ===
% 
% 1. run Kontroller by typing "Kontroller"
% 2. Kontroller will automatically detect NI hardware and determine
% which channels you can use
% 3. Click on "configure inputs". To configure analogue inputs, call
% the channel you want to use something in the text field. Specify the input range as a number in
% the smaller edit field.
% (default is +/-10V)
% 4. Click on "configure outputs".If you want to use an output channel, call
% it something in the text field. Analogue on left, digital on right.
% 5. click on "configure controls". you should have vectors corresponding
% to the control singals you want to write in your workspace. choose which
% vector is written to which channel. Call the entire set (a ControlParadigm) with a certain
% name, and click "DONE". Close the window if you're done adding control
% paradigms. 
% 6. Set an appropriate sampling rate. default is 1kHz. 
% 7. Choose the file you want to output data to. Data will be stored as a
% .mat file
% 8. Choose the input channels you want to look at, and press "start
% scopes" to look at your input live. 
% 9. If you want to run a trial, choose a control paradigm from the paradigm list
% and press "run"
% 10. Kontroller will save all data as .mat files in c:\data\
%
% === 2. Advanced Use: ControlParadigms ===
%
% 1. You can create your own ControlParadigms and save them to file, such
% that the name contains the string "*_Kontroller_paradigm*". Make sure
% this file contains a structure called ControlParadigm, where each element
% of the structure has a MxN array called Outputs, where M is the number of
% channels you want to write to, and N is the number of samples. Each
% element of ControlParadigm should also have a field called "Name" that is
% the name of the ControlParadigm. 
% 
% === 3.  Expert Use: Scripting Kontroller=
%
% Kontroller can be called as a function from your own script. 
% 
% Example Usage:
% 
% data = Kontroller('ControlParadigm',ControlParadigm,'RunTheseParadigms',[1 3],'w',1000);
%
% will run paradigms 1 and 3 in the ControlParadiagm Structure at 1000Hz
% and return the recorded data to a structure called data. 
%
% Note that you will have to use the GUI to configure inputs and outputs.
% Remember that the number of output channels must match the
% ControlParadigm! 
% 
% 
% ===Help, bug reports, contact and suggestions===
% 
% you should write to me at kontroller@srinivas.gs
%
% See also:
% http://github.com/sg-s/kontroller


function [data] = Kontroller(varargin)
VersionName= 'Kontroller v_94_';
%% validate inputs
gui = 0;
RunTheseParadigms = [];
ControlParadigm = []; % stores the actual control signals for the different control paradigm
w = 1000; % 1kHz sampling  
if nargin == 0 
    % fine.
    gui = 1; % default to showing the GUI
elseif iseven(nargin)
    for i = 1:nargin
        temp = varargin{i};
        if ischar(temp)
            eval(strcat(temp,'=varargin{i+1};'));
        end
    end
    clear i
    
    
else
    error('Inputs need to be name value pairs')
end



if ~gui
    if isempty(RunTheseParadigms) || isempty(ControlParadigm)
        error('Kontroller does not know what control paradigms to run.')
    end
end


%% check for MATLAB dependencies
v = ver;
v = struct2cell(v);
j = find(strcmp('Data Acquisition Toolbox', v), 1);
if ~isempty(j)
else
    % No DAQ toolbox
    error('Kontroller needs the <a href="http://www.mathworks.com/products/daq/">DAQ toolbox</a> to run, which was not detected.')
end
clear j

% check for internal dependencies
dependencies = {'oval','strkat','PrettyFig','CheckForNewestVersionOnGitHub'};
for i = 1:length(dependencies)
    if exist(dependencies{i}) ~= 2
        error('Kontroller is missing an external function that it needs to run. You can download it <a href="https://github.com/sg-s/srinivas.gs_mtools">here.</a>')
    end
end
clear i

% check for new version of Kontroller
if gui
    wh = waitbar(0.1,'Kontroller is starting...');
    try
        waitbar(0.2,wh,'Checking for updates...'); figure(wh)
        CheckForNewestVersionOnGitHub('kontroller',mfilename,VersionName);
    catch
        disp('Could not check for updates.')
    end
end



% check if data directory exists
if exist('c:\data\','dir') == 7
else
    if gui
        disp('Kontroller will default to storing recorded data in c:\data. This directory will now be created...')
    end
    mkdir('c:\data\')
end

%% persistent internal variables
 
% session handles
s=[]; % this is the session ID

% listeners
lh = []; % generic listener ID
lhMC = []; % listener for manual control

%  figure handles
f1 = []; f2=[]; f3 = []; f4 = [];
fcs=[];
mef = []; % figure for metadata editor
ViewParadigmFig = [];

% uicontrol handles
li = []; ri = []; lir = []; rir= [ ]; % analogue input handles
lo = []; ro = [];  % analogue outputs handles
dlo = []; dro = []; % digital outputs handles
MetadataTextControl= []; % handle for metadata control
MetadataTextDisplay = []; % handle for metadata display
ScopeHandles = [];
ControlHandles= [];
ParadigmNameUI = [];
MCoi = []; 
MCNumoi = []; % this is for manually entering a specific set point via a edit field

% internal control variables
MCOutputData = [];
metadatatext = []; % stores metadata in a cell array so that we can display it.
ScopeThese = [];
scopes_running = 0; % are the scopes running right now?
trial_running = 0; % when nonzero, this is the number of scans left. when zero, this means it's done
sequence = []; % this stores the sequence of trials to be done in this programme
sequence_step = []; % stores where in the sequence the programme is
programme_running = [];
pause_programme = 0;
% internal data variables
thisdata = []; % stores data from current trial; needs to be combined with data
data = [];
scope_plot_data = [];
time =[];
VarNames = [];
SaveToFile= [];
Trials = []; % this keeps track of how many trials have been done with each paradigm
metadata = [];  % stores metadata associated with the whole file. 
timestamps = []; % first column stores the paradigm #, the second the trial #, and the third the timestamp
Epochs = [];
CustomSequence = [];


%% initlaise some metadata
metadata.DateTime = datestr(now);
d = daq.getDevices;
metadata.daqName = d.Model;
metadata.KontrollerVersion = VersionName;
metadata.ComputerName = getenv('COMPUTERNAME');
metadata.SessionName = RandomString(10);
fn = fieldnames(metadata);
for i = 1:length(fn)
    metadatatext{i} = strcat(fn{i},' : ',mat2str(getfield(metadata,fn{i}))); %#ok<AGROW>
end
clear i
set(MetadataTextDisplay,'String',metadatatext);
set(MetadataTextControl,'String','');

%% make the GUI
if gui

    f1 = figure('Position',[20 60 450 700],'Toolbar','none','Menubar','none','Name',VersionName,'NumberTitle','off','Resize','off','HandleVisibility','on','CloseRequestFcn',@QuitKontrollerCallback);
    waitbar(0.3,wh,'Generating UI...'); figure(wh)
    Konsole = uicontrol('Position',[15 600 425 90],'Style','text','String','Kontroller is starting...','FontName','Courier','HorizontalAlignment','left');
    ConfigureInputChannelButton = uicontrol('Position',[15 540 140 50],'Style','pushbutton','Enable','off','String','Configure Inputs','FontSize',10,'Callback',@ConfigureInputChannels);
    ConfigureOutputChannelButton = uicontrol('Position',[160 540 140 50],'Style','pushbutton','Enable','off','String','Configure Outputs','FontSize',10,'Callback',@ConfigureOutputChannels);
    ConfigureControlSignalsButton = uicontrol('Position',[305 540 140 50],'Style','pushbutton','Enable','off','String','Configure Control','FontSize',10,'Callback',@ConfigureControlSignals);
    InputChannelsPanel = uipanel('Title','Input Channels','FontSize',12,'units','pixels','pos',[15 330 240 200]);
    PlotInputsList = {};
    PlotOutputsList = {};
    PlotInputs = uicontrol(InputChannelsPanel,'Position',[3 3 230 170],'Style','listbox','Min',0,'Max',2,'String',PlotInputsList,'FontSize',11);
    OutputChannelsPanel = uipanel('Title','Output Channels','FontSize',12,'units','pixels','pos',[265 330 170 130]);
    PlotOutputs = uicontrol(OutputChannelsPanel,'Position',[3 3 165 100],'Style','listbox','Min',0,'Max',2,'String',PlotOutputsList,'FontSize',11);

    % paradigm panel
    ControlParadigmList = {}; % stores a list of different control paradigm names. e.g., control, test, odour1, etc.
    ParadigmPanel = uipanel('Title','Control Paradigms','FontSize',12,'units','pixels','pos',[15 30 170 180]);
    ParadigmListDisplay = uicontrol(ParadigmPanel,'Position',[3 3 155 105],'Style','listbox','Enable','on','String',ControlParadigmList,'FontSize',12,'Min',0,'Max',2,'Callback',@ControlParadigmListCallback);
    SaveControlParadigmsButton = uicontrol(ParadigmPanel,'Position',[3,120,45,30],'Style','pushbutton','String','Save','Callback',@SaveControlParadigms);
    ViewControlParadigmButton = uicontrol(ParadigmPanel,'Position',[52,120,45,30],'Style','pushbutton','String','View','Callback',@ViewControlParadigm);
    RemoveControlParadigmsButton = uicontrol(ParadigmPanel,'Position',[100,120,60,30],'Style','pushbutton','String','Remove','Callback',@RemoveControlParadigms);

    % check to see if sampling rate is stored. 
    if exist('Kontroller.SamplingRate.mat','file') == 2
        load('Kontroller.SamplingRate.mat');
    else
        % default
        w = 1000;
    end
    SamplingRateControl = uicontrol(f1,'Position',[133 5 50 20],'Style','edit','String',mat2str(w),'Callback',@SamplingRateCallback);
    uicontrol(f1,'Position',[20 5 100 20],'Style','text','String','Sampling Rate');
    RunTrialButton = uicontrol(f1,'Position',[320 5 110 50],'Enable','off','BackgroundColor',[0.8 0.9 0.8],'Style','pushbutton','String','RUN w/o saving','FontWeight','bold','Callback',@RunTrial);

    FileNameDisplay = uicontrol(f1,'Position',[200,60,230,50],'Style','edit','String','No destination file selected','Callback',@SaveToFileTextEdit);
    FileNameSelect = uicontrol(f1,'Position',[200,5,100,50],'Style','pushbutton','String','Write to...','Callback',@SelectDestinationCallback);

    AutomatePanel = uipanel('Title','Automate','FontSize',12,'units','pixels','pos',[205 120 230 200]);
    uicontrol(AutomatePanel,'Style','text','FontSize',8,'String','Repeat selected paradigms','Position',[1 120 100 50])
    uicontrol(AutomatePanel,'Style','text','FontSize',8,'String','times','Position',[150 110 50 50])
    RepeatNTimesControl = uicontrol(AutomatePanel,'Style','edit','FontSize',8,'String','1','Position',[110 140 30 30]);
    RunProgramButton = uicontrol(AutomatePanel,'Position',[4 5 110 30],'Enable','off','Style','pushbutton','String','RUN PROGRAM','Callback',@RunProgram);
    PauseProgramButton = uicontrol(AutomatePanel,'Position',[124 5 80 30],'Enable','off','Style','togglebutton','String','PAUSE','Callback',@PauseProgram);
    AbortProgramButton = uicontrol(AutomatePanel,'Position',[124 40 80 30],'Enable','off','Style','togglebutton','String','ABORT');

    uicontrol(AutomatePanel,'Style','text','FontSize',8,'String','Do this between trials:','Position',[1 70 100 50])
    InterTrialIntervalControl = uicontrol(AutomatePanel,'Style','edit','FontSize',8,'String','pause(20)','Position',[110 100 100 30]);
    RandomizeControl = uicontrol(AutomatePanel,'Style','popupmenu','String',{'Randomise','Interleave','Block','Reverse Block','Custom'},'Value',2,'FontSize',8,'Position',[5 50 100 20],'Callback',@RandomiseControlCallback);


    ManualControlButton = uicontrol(f1,'Position',[10 230 170 30],'Enable','off','Style','pushbutton','String','Manual Control','Callback',@ManualControlCallback);
    MetadataButton = uicontrol(f1,'Position',[10 270 170 30],'Enable','on','Style','pushbutton','String','Add Metadata...','Callback',@MetadataCallback);

    waitbar(0.4,wh,'Generating global variables...'); figure(wh)
    StartScopes = uicontrol(f1,'Position',[260 465 150 50],'Style','pushbutton','Enable','off','String','Start Scopes','FontSize',12,'Callback',@ScopeCallback);
    scsz = get(0,'ScreenSize');
    scope_fig = figure('Position',[500 100 scsz(3)-500 scsz(4)-200],'Toolbar','none','Name','Oscilloscope','NumberTitle','off','Resize','on','Visible','off','CloseRequestFcn',@QuitKontrollerCallback); hold on; 

end

%% figure out DAQ characteristics and initialise

if gui
    waitbar(0.5,wh,'Scanning hardware...'); figure(wh)
else
    disp('Scanning hardware...')
end
d = daq.getDevices(); % this line takes a long time when you rin it for the first time...
if gui
    figure(wh)
end

OutputChannels =  d.Subsystems(2).ChannelNames;
nOutputChannels = length(OutputChannels);
InputChannels =  d.Subsystems(1).ChannelNames;
nInputChannels = length(InputChannels);
InputChannelRanges = 10*ones(1,nInputChannels);
DigitalOutputChannels=d.Subsystems(3).ChannelNames;
nDigitalOutputChannels = length(DigitalOutputChannels);
UsedInputChannels = [];
InputChannelNames = {}; % this is the user defined names
UsedDigitalOutputChannels = [];
DigitalOutputChannelNames = {}; % this is the user defined names
UsedOutputChannels = [];
OutputChannelNames = {}; % this is the user defined names

if gui
    waitbar(0.6,wh,'Checking for input config...'); figure(wh)
end
% load saved configs...inputs
if ~isempty(dir('Kontroller.Config.Input.mat'))
    
    load('Kontroller.Config.Input.mat','UsedInputChannels','InputChannelNames','InputChannelRanges')
    if gui
        disp('Loading saved input config files...')
        PlotInputsList = InputChannelNames(UsedInputChannels);
         set(PlotInputs,'String',PlotInputsList)
         if ~isempty(UsedInputChannels)
             set(StartScopes,'Enable','on')
         else 
             set(StartScopes,'Enable','off')
         end
         disp('DONE')
    end
    
end

% load sampling rate
if ~isempty(dir('Kontroller.Config.SamplingRate.mat'))
    
    load('Kontroller.Config.SamplingRate.mat','w')
    if gui
        disp('Loading saved sampling rate...')

         set(SamplingRateControl,'String',mat2str(w))
    end
    
end

if gui
    waitbar(0.7,wh,'Checking for output config...'); figure(wh)
end
% load saved configs..outputs
if gui
    set(ConfigureControlSignalsButton,'Enable','off')
end
if ~isempty(dir('Kontroller.Config.Output.mat'))
    
    load('Kontroller.Config.Output.mat','UsedOutputChannels','OutputChannelNames')
    if gui
        disp('Loading saved output config files...')
         if ~isempty(UsedOutputChannels)
             set(ConfigureControlSignalsButton,'Enable','on')
         end
         % update PlotOutputsList
         PlotOutputsList = [OutputChannelNames(UsedOutputChannels) DigitalOutputChannelNames(UsedDigitalOutputChannels)];
         set(PlotOutputs,'String',PlotOutputsList);
        disp('DONE')
    end
     
end
% load saved digital output configs
if ~isempty(dir('Kontroller.Config.Output.Digital.mat'))
    
    load('Kontroller.Config.Output.Digital.mat','UsedDigitalOutputChannels','DigitalOutputChannelNames')
    if gui
        disp('Loading saved output config files...')
         if ~isempty(UsedDigitalOutputChannels)
             set(ConfigureControlSignalsButton,'Enable','on')        
         end
         % update PlotOutputsList
         PlotOutputsList = [OutputChannelNames(UsedOutputChannels) DigitalOutputChannelNames(UsedDigitalOutputChannels)];
         set(PlotOutputs,'String',PlotOutputsList);
        disp('DONE')
    end
    
end
if gui
    waitbar(1,wh,'DONE.'); figure(wh)
    set(ConfigureInputChannelButton,'Enable','on')
    set(ConfigureOutputChannelButton,'Enable','on')
    set(Konsole,'String',strkat('Kontroller is ready to use. \n','Hardware detected: \n',d.Vendor.FullName,'-',d.Model))
    close(wh)
    set(scope_fig,'Visible','on')
end

%% the following section applies only when Kontroller is run in non-interactive mode.
if ~gui
    disp('Kontroller is starting from the command line...')
    for gi = 1:length(RunTheseParadigms)
        % prep the data acqusition session
        clear s
        s = daq.createSession('ni');
        % figure out T
        T = length(ControlParadigm(RunTheseParadigms(gi)).Outputs)/w;
        s.DurationInSeconds = T;
        s.Rate = w; % sampling rate, user defined.
        % add the analogue input channels
        TheseChannels=InputChannels(UsedInputChannels);
        for ii = 1:length(TheseChannels)
            s.addAnalogInputChannel('Dev1',InputChannels{UsedInputChannels(ii)}, 'Voltage');
        end
        % add the analogue output channels
        TheseChannels=OutputChannels(UsedOutputChannels);
        for ii = 1:length(TheseChannels)
             s.addAnalogOutputChannel('Dev1',OutputChannels{UsedOutputChannels(ii)}, 'Voltage');
        end
        % add the digital output channels
        TheseChannels=DigitalOutputChannels(UsedDigitalOutputChannels);
        for ii = 1:length(TheseChannels)
             s.addDigitalChannel('Dev1',DigitalOutputChannels{UsedDigitalOutputChannels(ii)}, 'OutputOnly');
        end
        
        % queue data        
        s.queueOutputData(ControlParadigm(RunTheseParadigms(gi)).Outputs');
        
        % configure listener to plot data on the scopes 
        lh = s.addlistener('DataAvailable',@PlotCallback);
        scope_plot_data = NaN(length(UsedInputChannels),T*w);
        
        % run trial
        disp('Running trial...')
        
        
        s.startForeground();
        disp('DONE')
        
        ThisParadigm = RunTheseParadigms(gi);
        ProcessTrialData;
        
    end
end

%% configure inputs
    function [] =ConfigureInputChannels(eo,ed)
        % load saved configs      
        n = nInputChannels;
        Height = 600;
        f2 = figure('Position',[80 80 450 Height+50],'Toolbar','none','Menubar','none','resize','off','Name','Configure Analogue Input Channels','NumberTitle','off');
        uicontrol(f2,'Position',[25 600 400 40],'style','text','String','To reduce channel cross-talk, label shorted channels as "Ground". These will not be recorded from.','FontSize',8);
        a = axes; hold on
        set(a,'Visible','off');
        if floor(n/2)*2 == n
            % even n
            nspacing = Height/(n/2);
            % generate UIcontrol edit boxes
            for i = 1:n/2  % left side
                if ismember(i,UsedInputChannels)
                    li(i) = uicontrol(f2,'Position',[40 10+Height-i*nspacing 100 20],'Style', 'edit','String',InputChannelNames{i},'FontSize',12,'Callback',@InputConfigCallback);
                    lir(i) = uicontrol(f2,'Position',[7 10+Height-i*nspacing 25 20],'Style', 'edit','String',mat2str(InputChannelRanges(i)),'FontSize',10,'Callback',@InputConfigCallback);
                    % check if it is a ground channel
                      if strmatch(get(li(i),'String'),'Ground')
                          set(li(i),'ForegroundColor','g')
                      else
                          set(li(i),'ForegroundColor','k')
                      end
                else
                    li(i) = uicontrol(f2,'Position',[40 10+Height-i*nspacing 100 20],'Style', 'edit','FontSize',12,'Callback',@InputConfigCallback);
                    lir(i) = uicontrol(f2,'Position',[7 10+Height-i*nspacing 25 20],'Style', 'edit','String',mat2str(InputChannelRanges(i)),'FontSize',10,'Callback',@InputConfigCallback);
                end
                uicontrol(f2,'Position',[160 10+Height-i*nspacing 50 20],'Style', 'text','String',InputChannels{i},'FontSize',12);
            end
            clear i
            for i = 1:n/2  % right side
                if ismember(n/2+i,UsedInputChannels)
                    ri(i) = uicontrol(f2,'Position',[300 10+Height-i*nspacing 100 20],'Style', 'edit','String',InputChannelNames{n/2+i},'FontSize',12,'Callback',@InputConfigCallback);
                    rir(i) = uicontrol(f2,'Position',[407 10+Height-i*nspacing 25 20],'Style', 'edit','String',mat2str(InputChannelRanges(n/2+i)),'FontSize',10,'Callback',@InputConfigCallback);
                    % check if it is a ground channel
                      if strmatch(get(ri(i),'String'),'Ground')
                          set(ri(i),'ForegroundColor','g')
                      else
                          set(ri(i),'ForegroundColor','k')
                      end
                else
                    ri(i) = uicontrol(f2,'Position',[300 10+Height-i*nspacing 100 20],'Style', 'edit','FontSize',12,'Callback',@InputConfigCallback);
                    rir(i) = uicontrol(f2,'Position',[407 10+Height-i*nspacing 25 20],'Style', 'edit','String',mat2str(InputChannelRanges(n/2+i)),'FontSize',10,'Callback',@InputConfigCallback);
                end
                uicontrol(f2,'Position',[220 10+Height-i*nspacing 50 20],'Style', 'text','String',InputChannels{n/2+i},'FontSize',12);
            end
            clear i
            
        else
            error('Odd number of channels, cannot handle this')
        end
    
    end

%% configure outputs
    function [] =ConfigureOutputChannels(eo,ed)
        % make the analogue outputs
        n = nOutputChannels;
        Height = 300;
        f3 = figure('Position',[50 150 450 Height],'Toolbar','none','Menubar','none','Name','Configure Analogue Output Channels','NumberTitle','off','CloseRequestFcn',@QuitConfigOutputsCallback);
        a = axes; hold on
        set(a,'Visible','off');
        if floor(n/2)*2 == n
            % even n
            nspacing = Height/(n/2+1);
            % generate UIcontrol edit boxes
            for i = 1:n/2  % left side
                if ismember(i,UsedOutputChannels)
                    lo(i) = uicontrol(f3,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','String',OutputChannelNames{i},'FontSize',12,'Callback',@OutputConfigCallback);
                else
                    lo(i) = uicontrol(f3,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','FontSize',12,'Callback',@OutputConfigCallback);
                end
                uicontrol(f3,'Position',[160 Height-i*nspacing 50 20],'Style', 'text','String',OutputChannels{i},'FontSize',12);
            end
            clear i
            for i = 1:n/2  % right side
                if ismember(n/2+i,UsedOutputChannels)
                    
                    ro(i) = uicontrol(f3,'Position',[300 Height-i*nspacing 100 20],'Style', 'edit','String',OutputChannelNames{n/2+i},'FontSize',12,'Callback',@OutputConfigCallback);
                else
                    ro(i) = uicontrol(f3,'Position',[300 Height-i*nspacing 100 20],'Style', 'edit','FontSize',12,'Callback',@OutputConfigCallback);
                end
                uicontrol(f3,'Position',[220 Height-i*nspacing 50 20],'Style', 'text','String',OutputChannels{n/2+i},'FontSize',12);
            end
            clear i
            
        else
            error('Odd number of channels, cannot handle this')
        end
        
        % make the digital outputs
        n = nDigitalOutputChannels;
        Height = 700;
        f4 = figure('Position',[550 150 550 Height],'Resize','off','Toolbar','none','Menubar','none','Name','Configure Digital Output Channels','NumberTitle','off','CloseRequestFcn',@QuitConfigOutputsCallback);
        a = axes; hold on
        set(a,'Visible','off');
        if floor(n/2)*2 == n
            % even n
            nspacing = Height/(n/2+1);
            % generate UIcontrol edit boxes
            for i = 1:n/2  % left side
                if ismember(i,UsedDigitalOutputChannels)
                    dlo(i) = uicontrol(f4,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','String',DigitalOutputChannelNames{i},'FontSize',10,'Callback',@OutputConfigCallback);
                else
                    dlo(i) = uicontrol(f4,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','FontSize',10,'Callback',@OutputConfigCallback);
                end
                uicontrol(f4,'Position',[160 Height-i*nspacing 100 20],'Style', 'text','String',DigitalOutputChannels{i},'FontSize',10);
            end
            clear i
            for i = 1:n/2  % right side
                if ismember(n/2+i,UsedOutputChannels)
                    
                    dro(i) = uicontrol(f4,'Position',[390 Height-i*nspacing 100 20],'Style', 'edit','String',DigitalOutputChannelNames{n/2+i},'FontSize',10,'Callback',@OutputConfigCallback);
                else
                    dro(i) = uicontrol(f4,'Position',[390 Height-i*nspacing 100 20],'Style', 'edit','FontSize',10,'Callback',@OutputConfigCallback);
                end
                uicontrol(f4,'Position',[280 Height-i*nspacing 100 20],'Style', 'text','String',DigitalOutputChannels{n/2+i},'FontSize',10);
            end
            clear i
            
        else
            error('Odd number of channels, cannot handle this')
        end
    
    end

%% manual control callback
function [] =ManualControlCallback(eo,ed)
        % stop scopes
        if scopes_running
            % stop scopes
            s.stop;
            delete(lh);
            % relabel scopes button
            set(StartScopes,'String','Start Scopes');
            scopes_running = 0;
        end
        % stop trial if necessary
        if trial_running
            error('Trial running, wait for trial to finish')
        end
        
        % make UI
        n = nOutputChannels;
        Height = 300;
        fMC = figure('Position',[60 50 650 Height],'Toolbar','none','Menubar','none','Name','Manual Control','NumberTitle','off','CloseRequestFcn',@QuitManualControlCallback);
        a = axes; hold on
        set(a,'Visible','off');
        if floor(n/2)*2 == n
            % even n
            nspacing = Height/(n/2+1);
            % generate UIcontrol edit boxes
            oi=1; % this is the index of each used ouput channel
            for i = 1:n/2  % left side
                if ismember(i,UsedOutputChannels)
                    MCoi(oi) = uicontrol(fMC,'Position',[90 Height-i*nspacing 100 20],'Style', 'slider','Min',0,'Max',5,'Value',0,'String',OutputChannelNames{i},'FontSize',16,'Callback',@ManualControlSliderCallback);
                    uicontrol(fMC,'Position',[220 Height-i*nspacing 50 20],'Style', 'text','String',OutputChannels{i},'FontSize',12);
                    MCNumoi(oi) = uicontrol(fMC,'Position',[20 Height-i*nspacing 60 20],'Style', 'edit','String','0','FontSize',12,'Callback',@ManualControlSliderCallback);
                    oi = oi +1; 
                end
            end
            clear i
            for i = 1:n/2  % right side  
                if ismember(i+n/2,UsedOutputChannels)
                    MCoi(oi) = uicontrol(fMC,'Position',[390 Height-i*nspacing 100 20],'Style', 'slider','Min',0,'Max',5,'Value',0,'String',OutputChannelNames{n/2+i},'FontSize',16,'Callback',@ManualControlSliderCallback);
                    uicontrol(fMC,'Position',[320 Height-i*nspacing 50 20],'Style', 'text','String',OutputChannels{(n/2+i)},'FontSize',12);
                    MCNumoi(oi) = uicontrol(fMC,'Position',[520 Height-i*nspacing 60 20],'Style', 'edit','String','0','FontSize',12,'Callback',@ManualControlSliderCallback);
                    oi = oi +1;
                end
            end
            clear i
            
        else
            % odd number of channels
            error('Odd number of channels. Cant handle this')
        end
        
        % configure session
        figure(scope_fig)   
        s = daq.createSession('ni');
        s.IsContinuous = true;
        s.Rate = w; 
        
        % configure session inputs
        s.NotifyWhenDataAvailableExceeds = 100; % 10Hz 
        % update scope_plot_data
        scope_plot_data = NaN(length(get(PlotInputs,'Value')),5000); % 5 s of  data in each channel
        ScopeHandles = []; % axis handles for each sub plot in scope
        rows = ceil(length(get(PlotInputs,'Value'))/2);
        ScopeThese = get(PlotInputs,'Value');
        for i = 1:length(get(PlotInputs,'Value'))
            ScopeHandles(i) = subplot(2,rows,i);
            plotname=strcat(InputChannels{UsedInputChannels(i)},'-',InputChannelNames{UsedInputChannels(i)});
            ylabel(plotname)
            set(ScopeHandles(i),'XLim',[0 5000]), hold on
            s.addAnalogInputChannel('Dev1',InputChannels{UsedInputChannels(ScopeThese(i))}, 'Voltage'); % add channel
        end
        clear i
        lh = s.addlistener('DataAvailable',@PlotCallback);
        
        
        % configure session outputs
        MCOutputData = zeros(length(UsedOutputChannels),500)'; 
        TheseChannels=OutputChannels(UsedOutputChannels);
        for i = 1:length(TheseChannels)
             s.addAnalogOutputChannel('Dev1',OutputChannels{UsedOutputChannels(i)}, 'Voltage');
        end
        clear i
        s.queueOutputData(MCOutputData);
        %s.NotifyWhenScansQueuedBelow = 100; % this line causes random
        %stops; don't know why
        lhMC = s.addlistener('DataRequired',@(src,event) src.queueOutputData(MCOutputData));
        
        % start it
        s.ExternalTriggerTimeout = 100;
        s.startBackground();
        scopes_running= 1;
        
        

        
    
end

%% manual control slider and text entry callback
% bug here -- slider doesnt work becauyse its overwritten by the text edit
    function ManualControlSliderCallback(eo,ed)
        for i = 1:length(UsedOutputChannels)
            thisvalue = get(MCoi(i),'Value');
            MCOutputData(:,i) = thisvalue*ones(500,1);
        end
        clear i
        % now check text entry fields. this overrides the slider
        for i = 1:length(UsedOutputChannels)
            thisvalue = str2double(get(MCNumoi(i),'String'));
            MCOutputData(:,i) = thisvalue*ones(500,1);
        end
        clear i
        
        delete(lhMC)
        lhMC = s.addlistener('DataRequired',@(src,event) src.queueOutputData(MCOutputData));
        
        
        
    end

%% input config callback
    function [] = InputConfigCallback(eo,ed)
        UsedInputChannels = [];
        n = nInputChannels;
         % first scan left
         for i = 1:n/2
              if isempty(strmatch(get(li(i),'String'),InputChannels))
                  % use this channel
                  UsedInputChannels = [UsedInputChannels i];

                  InputChannelNames{i} = get(li(i),'String');
                  InputChannelRanges(i) = str2double(get(lir(i),'String'));
                  % check if it is a ground channel
                  if strcmp(get(li(i),'String'),'Ground')
                      set(li(i),'ForegroundColor','g')
                  else
                      set(li(i),'ForegroundColor','k')
                  end
              
              end
              
         end
         clear i
         % then scan right
         for i = 1:n/2
              if isempty(strmatch(get(ri(i),'String'),InputChannels))
                  % use this channel
                  UsedInputChannels = [UsedInputChannels n/2+i];
                  InputChannelNames{n/2+i} = get(ri(i),'String');
                  InputChannelRanges(n/2+i) = str2double(get(rir(i),'String'));
                  % check if it is a ground channel
                  if strcmp(get(ri(i),'String'),'Ground')
                      set(ri(i),'ForegroundColor','g')
                  else
                      set(ri(i),'ForegroundColor','k')
                  end
              end
         end
         clear i
         
         % update the input channel list
         PlotInputsList = InputChannelNames(UsedInputChannels);
         set(PlotInputs,'String',PlotInputsList)
         if ~isempty(UsedInputChannels)
             set(StartScopes,'Enable','on')
             
         else 
             set(StartScopes,'Enable','off')
         end
         % save Input Channel Names for persisitent config
         save('Kontroller.Config.Input.mat','InputChannelNames','UsedInputChannels','InputChannelRanges');
        
    end

%% output config callback
function [] = OutputConfigCallback(eo,ed)
    % configure analogue outputs
        UsedOutputChannels = [];
        n = nOutputChannels;
         % first scan left
         for i = 1:n/2
              if isempty(strmatch(get(lo(i),'String'),OutputChannels))
                  % use this channel
                  UsedOutputChannels = [UsedOutputChannels i];
                  OutputChannelNames{i} = get(lo(i),'String');
              end
         end
         clear i
         % then scan right
         for i = 1:n/2
              if isempty(strmatch(get(ro(i),'String'),OutputChannels))
                  % use this channel
                  UsedOutputChannels = [UsedOutputChannels n/2+i];
                  OutputChannelNames{n/2+i} = get(ro(i),'String');
              end
         end
         clear i
         
         % update the output channel control signal config
         if ~isempty(UsedOutputChannels)
             set(ConfigureControlSignalsButton,'Enable','on')
             
         else 
             set(ConfigureControlSignalsButton,'Enable','off')
         end
         % now update digital outputs
         DigitalOutputChannelNames = {};
         UsedDigitalOutputChannels = [];
         n = nDigitalOutputChannels;
         % first scan left
         for i = 1:n/2
              if isempty(strmatch(get(dlo(i),'String'),DigitalOutputChannels))
                  % use this channel
                  UsedDigitalOutputChannels = [UsedDigitalOutputChannels i];
                  DigitalOutputChannelNames{i} = get(dlo(i),'String');
              end
         end
         clear i
         % then scan right
         for i = 1:n/2
              if isempty(strmatch(get(dro(i),'String'),DigitalOutputChannels))
                  % use this channel
                  UsedDigitalOutputChannels = [UsedDigitalOutputChannels n/2+i];
                  DigitalOutputChannelNames{n/2+i} = get(dro(i),'String');
              end
         end
         clear i
         
         % update the output channel control signal config
         if ~isempty(UsedOutputChannels) || ~isempty(UsedDigitalOutputChannels)
             set(ConfigureControlSignalsButton,'Enable','on')
             
         else 
             set(ConfigureControlSignalsButton,'Enable','off')
         end
         
         PlotOutputsList = [OutputChannelNames(UsedOutputChannels) DigitalOutputChannelNames(UsedDigitalOutputChannels)];
         set(PlotOutputs,'String',PlotOutputsList)
         % save Analogue Output Channel Names for persisitent config
         
         save('Kontroller.Config.Output.mat','OutputChannelNames','UsedOutputChannels');
         
         % save Digital Output Channel Names for persisitent config
         save('Kontroller.Config.Output.Digital.mat','DigitalOutputChannelNames','UsedDigitalOutputChannels');
        
end

%% Sampling Rate Callback
    function [] = SamplingRateCallback(~,~)
        w = str2double(get(SamplingRateControl,'String'));
        % write to file
        save('Kontroller.SamplingRate.mat','w')
    end


%% oscilloscope callback
    function  [] = ScopeCallback(eo,ed)
        if isempty(PlotInputsList)
        else
            if scopes_running
                % stop scopes
                s.stop;
                delete(lh);
                % relabel scopes button
                set(StartScopes,'String','Start Scopes');
                scopes_running = 0;
            else
                % start scopes
                figure(scope_fig)   
                % create session
                s = daq.createSession('ni');
                s.IsContinuous = true;
                s.NotifyWhenDataAvailableExceeds = w/10; % 10Hz
                % update scope_plot_data
                scope_plot_data = NaN(length(get(PlotInputs,'Value')),5*w); % 5 s of  data in each channel
                time = (1/w):(1/w):5;
                ScopeHandles = []; % axis handles for each sub plot in scope
                rows = ceil(length(get(PlotInputs,'Value'))/2);
                ScopeThese = get(PlotInputs,'Value');
                for i = 1:length(get(PlotInputs,'Value'))
                    ScopeHandles(i) = subplot(2,rows,i);
                    set(ScopeHandles(i),'XLim',[0 5000]), hold off
                    ylabel( strcat(InputChannels{UsedInputChannels(i)},' -- ',InputChannelNames{UsedInputChannels(i)}))
                    s.addAnalogInputChannel('Dev1',InputChannels{UsedInputChannels(ScopeThese(i))}, 'Voltage'); % add channel
                end
                clear i
                
                
                s.Rate = w; 
                lh = s.addlistener('DataAvailable',@ScopePlotCallback);
                
                % specify each channel's range
                for i = 1:length(s.Channels)
                    % figure out which channel it is
                    [a,~]=ind2sub(size(InputChannels), strmatch(s.Channels(i).ID, InputChannels, 'exact'));
                    s.Channels(i).Range = InputChannelRanges(a)*[-1 1];
                end
                clear i
                
                % fix scope labels
                ScopeThese = 1:length(get(PlotInputs,'Value'));
                
                % relabel scopes button
                set(StartScopes,'String','Stop Scopes');
                s.startBackground();
                scopes_running = 1;
   
            end
       
        end   
    end

    function [] = ScopePlotCallback(src,event)
        sz = size(scope_plot_data);
        
        % figure out the size of the data increment      
        dsz = length(event.Data);
        
        % throw out the first bit of scope_plot_data
        scope_plot_data(:,1:dsz) = [];
        
        % append the new data to the end
        scope_plot_data = [scope_plot_data event.Data'];
        
        
        
        for si = ScopeThese
            plot(ScopeHandles(si),time,scope_plot_data(si,:));
        end
    end


%% plot live data to scopes and grab data
    function [] = PlotCallback(src,event)
        sz = size(scope_plot_data);
        % capture all the data acquired...        
        a =  find(isnan(scope_plot_data(1,:)),1,'first');
        z =  a + length(event.Data);
        for si = 1:sz(1)
            scope_plot_data(si,a:z-1) = event.Data(:,si)';
        end
        
        % ...but plot only the ones requested
        if gui
            % if this is being called as part of an experiment, use
            % EpochPlot
            EpochPlot(ScopeHandles(ScopeThese),ScopeThese,time,scope_plot_data,Epochs);
            trial_running = trial_running - 1;
        else
            if rand>0.9
                fprintf('.')
            end
        end
        
    end

%% configure control signals
    function [] = ConfigureControlSignals(eo,ed)
        no = length(UsedOutputChannels) + length(UsedDigitalOutputChannels);
        Height = 100+no*100;
        % figure out the variables in the workspace that you can use. 
        % we require them to be a 1D vector. that's it. 
        var=evalin('base','whos');
        badvar=  [];
        for i  =1:length(var)
            if  ~((length(var(i).size)==2) || (min(var(i).size) == 1))
                badvar = [badvar i];
            end
        end
        clear i
        var(badvar) = []; clear badvar
        
        % make the gui
        fcs= figure('Position',[200 200 450 Height],'Toolbar','none','Menubar','none','Name','Select Control Signals','NumberTitle','off','Resize','off');
        ControlHandles = [];
        if length(var) >= no
            % assemble names into a cell array
            VarNames = {};
            for i = 1:length(var)
                VarNames{i} = var(i).name;
            end
            
            
            % get name of control paradigm
            ParadigmNameUI=uicontrol(fcs,'Position',[(450-340)/2 Height-30 340 24],'Style', 'edit','String','Enter Name of Control Paradigm','FontSize',12);
            
            
            for i = 1:length(UsedOutputChannels)
                ControlHandles(i) = uicontrol(fcs,'Position',[150 10+i*100 150 50],'Style','popupmenu','Enable','on','String',VarNames,'FontSize',12);
                uicontrol(fcs,'Position',[30 30+i*100 100 30],'Style','text','String',OutputChannels{UsedOutputChannels(i)},'FontSize',12);
                uicontrol(fcs,'Position',[320 30+i*100 100 30],'Style','text','String',OutputChannelNames{UsedOutputChannels(i)},'FontSize',12);

            end
            clear i
            ti=1;
            for i = length(UsedOutputChannels)+1:no
                ControlHandles(i) = uicontrol(fcs,'Position',[150 10+i*100 150 50],'Style','popupmenu','Enable','on','String',VarNames,'FontSize',12);
                uicontrol(fcs,'Position',[30 30+i*100 100 30],'Style','text','String',DigitalOutputChannels{UsedDigitalOutputChannels(ti)},'FontSize',12);
                uicontrol(fcs,'Position',[320 30+i*100 100 30],'Style','text','String',DigitalOutputChannelNames{UsedDigitalOutputChannels(ti)},'FontSize',12);
                ti=ti+1;
            end
            
            clear ti
            % button to save paradigm
            uicontrol(fcs,'Position',[370 30 60 30],'Style','pushbutton','String','+Add','FontSize',12,'Callback',@ConfigureControlCallback);

        else
            % tell the user they don't enough variables to configure controls
            uicontrol(fcs,'Position',[25 70 400 200],'Style','text','String','To manually configure a control paradigm, you must have at least as many vectors in your MATLAB workspace as you have analogue outputs. This is not the case. Either close this and create some, or load a previously saved control paradigm from file. ','FontSize',12);
        
        end
        
        % button for loading saved control paradigms
        uicontrol(fcs,'Position',[10 30 260 30],'Style','pushbutton','String','Load saved paradigms...','FontSize',12,'Callback',@LoadSavedParadigms);
        
        
        
    end

%% configure control callback
    function [] = ConfigureControlCallback(eo,ed)
        no = length(UsedOutputChannels) + length(UsedDigitalOutputChannels);
        % assume everything is OK, and make a paradigm
        ControlParadigm(length(ControlParadigm)+1).Name= get(ParadigmNameUI,'String');
        thisp = length(ControlParadigm);
        % and now fill in the analogue control signals
        for i = 1:length(UsedOutputChannels);
            ControlParadigm(thisp).Outputs(i,:)=evalin('base',cell2mat(VarNames(get(ControlHandles(i),'Value'))));
        end
        % now fill in the digital control signals
        ti=1;
        for i = length(UsedOutputChannels)+1:no
            ControlParadigm(thisp).Outputs(i,:)=evalin('base',cell2mat(VarNames(get(ControlHandles(i),'Value'))));
            ti=ti+1;
        end
        clear i

        % update the paradigm list
        ControlParadigmList = [ControlParadigmList get(ParadigmNameUI,'String')];
        set(ParadigmListDisplay,'String',ControlParadigmList)
        
        % update Trial count
        Trials = zeros(1,length(ControlParadigmList));
        set(Konsole,'String','Controls have been configured. ')
        
        % enable the run button
        set(RunTrialButton,'enable','on','String','RUN w/o saving','BackgroundColor',[0.9 0.1 0.1]);
    end

%% select destintion callback
    function [] = SelectDestinationCallback(eo,ed)
        temp=strcat(datestr(now,'yyyy_mm_dd'),'_customname.mat');
        SaveToFile=uiputfile(strcat('C:\data\',temp));
        % activate the run buttons
        if length(get(ParadigmListDisplay,'Value')) == 1
            set(RunTrialButton,'enable','on','BackgroundColor',[0.1 0.9 0.1],'String','RUN and SAVE');
        end
        set(RunProgramButton,'enable','on');
        % update display
        set(FileNameDisplay,'String',SaveToFile);
        % reset Trial count
        Trials = zeros(1,length(ControlParadigmList)); 
        timestamps = [];
        data = []; % clears the data, so that new data is written to the new file
        sequence=  [];
        sequence_step = [];
         
    end

%% save to file destination callback
    function [] = SaveToFileTextEdit(eo,ed)
        if isempty(get(FileNameDisplay,'String'))
            % no destination
            if length(get(ParadigmListDisplay,'Value')) == 1
                set(RunTrialButton,'enable','on','BackgroundColor',[0.9 0.1 0.1],'String','RUN w/o saving');
            end
        else
            if exist(strcat('c:\data\',get(FileNameDisplay,'String')),'file')
                % file already exists, will overwrite
                set(FileNameDisplay,'ForegroundColor','r')
            else
                % new file
                set(FileNameDisplay,'ForegroundColor','k')
            end
            if length(get(ParadigmListDisplay,'Value')) == 1
                set(RunTrialButton,'enable','on','BackgroundColor',[0.1 0.9 0.1],'String','RUN and SAVE');
            end
            % reset Trial count
            Trials = zeros(1,length(ControlParadigmList)); 
            % reset timestamps
            timestamps = [];
            data = []; % clears the data, so that new data is written to the new file
            sequence=  [];
            sequence_step = [];
            SaveToFile = get(FileNameDisplay,'String');
        end
            
    end
%% RandimzeControl Callbacl -- for custom sequence
    function [] = RandomiseControlCallback(eo,ed)
        % get sequence
        if  get(RandomizeControl,'Value') == 5
            CustomSequence = inputdlg('Enter sequence of paradigms in program:','Choose custom sequence');
            set(Konsole,'string',strkat('This custom programme of the following pradigms configured: ',CustomSequence{1}))
        end
        
    end

%% run programmme
    function [] = RunProgram(eo,ed)
        % make sure pause programme button is enabled
        set(PauseProgramButton,'Enable','on');
        set(AbortProgramButton,'Enable','on');
        
        
        % check if pause is required
        if get(PauseProgramButton,'Value') 
            set(PauseProgramButton,'String','PAUSED')
        end
        while get(PauseProgramButton,'Value') == 1  
            pause(0.1)
        end

        if ~get(AbortProgramButton,'Value')    
        
            % figure out how many trials have been run so far
            if isempty(sequence)
                % start the timer
                tic
                % make the sequence
                np = get(ParadigmListDisplay,'Value');

                ntrials= str2num(get(RepeatNTimesControl,'String'));

                % figure out how to arrange paradigms
                switch get(RandomizeControl,'Value') 
                    case 1
                        % randomise
                        sequence = repmat(np,1,ntrials);
                        sequence = sequence(randperm(length(sequence),length(sequence)));
                    case 2
                        % interleave
                        sequence = repmat(np,1,ntrials);
                    case 3
                        % block
                        sequence =  reshape((np'*ones(1,ntrials))',1,ntrials*length(np));
                    case 4
                        % reverse block
                        sequence =  reshape((np'*ones(1,ntrials))',1,ntrials*length(np));
                        sequence = fliplr(sequence);
                    case 5
                        % arbitrary
                        if ~isempty(CustomSequence)
                            sequence =  str2num(CustomSequence{1}); %#ok<ST2NM>
                        else
                            error('Cannot find custom sequence.')
                        end

                end


                sequence_step = 1;
                programme_running = 1;
                set(RunProgramButton,'Enable','off')
                set(RunTrialButton,'Enable','off')
            end


            if sequence_step < length(sequence) + 1
                % update time estimates
                t=toc;
                if t < 2
                    % programme just started
                    ks = strkat('Running inter-trial function....');
                else
                    tt=(t/(sequence_step-1))*length(sequence) - t; % time remaining
                    tt=oval(tt,2);
                    t=oval(toc,2);
                    ks = strkat('Running inter-trial function....','\n','Elapsed time is :', (t), 'seconds'...
                   ,'\n',(tt),'seconds remain');
                end


                % run inter-trial function
                iti = (get(InterTrialIntervalControl,'String'));
                set(Konsole,'String',ks)
                eval(iti)

                % check if pause is required
                if get(PauseProgramButton,'Value') 
                    set(PauseProgramButton,'String','PAUSED')
                end
                while get(PauseProgramButton,'Value') == 1  
                    pause(0.1)
                end


                % run the correct step of the sequence
                set(ParadigmListDisplay,'Value',sequence(sequence_step));
                sequence_step = sequence_step + 1;
                RunTrial; 

            else  
                % programme has finished running
                programme_running = 0;
                set(Konsole,'String','Programme has finished running.')
                set(RunProgramButton,'Enable','on')
                set(RunTrialButton,'Enable','on')
                set(PauseProgramButton,'Enable','off')
                set(AbortProgramButton,'Enable','off');

                % re-select the initially selected paradgims
                set(ParadigmListDisplay,'Value',unique(sequence));

                sequence = [];
                sequence_step = [];

                beep
                pause(0.1)
                beep


            end
        else
            % abort!
            programme_running = 0;
            set(Konsole,'String','Programme has been aborted!')
            set(RunProgramButton,'Enable','on')
            set(RunTrialButton,'Enable','on')
            set(PauseProgramButton,'Enable','off')
            set(AbortProgramButton,'Enable','off');

            % re-select the initially selected paradgims
            try
                set(ParadigmListDisplay,'Value',unique(sequence));
            catch
            end

            sequence = [];
            sequence_step = [];

            beep
            beep
            pause(0.1)
            beep
            beep
            
            set(AbortProgramButton,'Value',0)
            
        end
    end

%% pause program
    function [] = PauseProgram(eo,ed)
        if pause_programme
            set(PauseProgramButton,'String','PAUSE');
            pause_programme = 0;
        else
            set(PauseProgramButton,'String','Pausing...')
            pause_programme = 1;
        end
        
        
    end

%% control paradigm list callback
    function [] = ControlParadigmListCallback(eo,ed)
        % how many paradigms selected?
        if length(get(ParadigmListDisplay,'Value')) > 1
            % more than one. so unset RUN
            set(RunTrialButton,'Enable','off');
            set(ViewControlParadigmButton,'Enable','off');
        else 
            set(ViewControlParadigmButton,'Enable','on');
            % check if destination is OK
            
                set(RunTrialButton,'Enable','on');
            
        end
        if Trials(get(ParadigmListDisplay,'Value'))
            showthis = strkat(mat2str(Trials(get(ParadigmListDisplay,'Value'))),'  trials recorded on selected Paradigm(s)');
            set(Konsole,'String',showthis)
        else
            % no trials on this paradigm
            set(Konsole,'String','No trials have been recorded on selected paradigm(s).')
        end
    end

%% view control paradigm callback
    function [] = ViewControlParadigm(eo,ed)
        % try to close previous figure
        try 
            close(ViewParadigmFig)
        catch
        end

        % there are length(UsedOutputChannels) outputs
        no = length(UsedOutputChannels) + length(UsedDigitalOutputChannels);

        % figure out how to arrange subplots
        nrows = floor(sqrt(no));
        ncols = ceil(no/nrows);
        
        ViewParadigmFig = figure('Position',[500 150 750 650],'Toolbar','none','Menubar','none','Name','Control Signals','NumberTitle','off','Resize','on'); hold on; 
        hold on
        sr = str2double(get(SamplingRateControl,'String'));
        t  = (1:length(ControlParadigm(get(ParadigmListDisplay,'Value')).Outputs))/sr;
        ocn = [OutputChannelNames(UsedOutputChannels) DigitalOutputChannelNames(UsedDigitalOutputChannels)];
        for vi = 1:no
            subplot(nrows,ncols,vi); hold on
            plot(t,ControlParadigm(get(ParadigmListDisplay,'Value')).Outputs(vi,:),'LineWidth',2);
            set(gca,'XLim',[0 max(t)])
            title(ocn{vi},'FontSize',20,'Interpreter','none')
        end
        PrettyFig('EqualiseY =1;','fs=18;')
        
    end

%% run trial
    function [] = RunTrial(eo,ed) 

        % disable all buttons
        set(ConfigureInputChannelButton,'Enable','off');
        set(ConfigureOutputChannelButton,'Enable','off');
        set(ConfigureControlSignalsButton,'Enable','off');
        set(RunProgramButton,'Enable','off');
        set(PauseProgramButton,'Enable','off');
        set(StartScopes,'Enable','off');
        set(MetadataButton,'Enable','off');
        set(ManualControlButton,'Enable','off');
        set(FileNameSelect,'Enable','off');
        set(SaveControlParadigmsButton,'Enable','off');
        set(RemoveControlParadigmsButton,'Enable','off');
        
        ComputeEpochs;
        
        
        
        if scopes_running
            % stop scopes
            s.stop;
            delete(lh);
            % relabel scopes button
            set(StartScopes,'String','Start Scopes');
            scopes_running = 0;
        end
            
        set(RunTrialButton,'Enable','off','String','running...')
        % figure out which pradigm to run
        ThisParadigm= (get(ParadigmListDisplay,'Value'));
        
        time=(1/w):(1/w):(length(ControlParadigm(ThisParadigm).Outputs)/w);
        
        % figure out trial no
        if ~length(data)
            % no data at all
            Trials(ThisParadigm) = 1;
            set(Konsole,'String',strkat('Running Trial: \n','Paradigm: \t \t  ',ControlParadigmList{ThisParadigm},'\n Trial: \t \t ','1'))
        else
            if length(data) < ThisParadigm
            
                % first trial in this paradigm
                Trials(ThisParadigm) = 1;
                set(Konsole,'String',strkat('Running Trial: \n','Paradigm: \t \t  ',ControlParadigmList{ThisParadigm},'\n Trial:\t \t ',mat2str(1)))
       
            else
                sz = [];
                eval(strcat('sz=size(data(ThisParadigm).',InputChannelNames{UsedInputChannels(1)},');'));
                Trials(ThisParadigm) = sz(1)+1;
                set(Konsole,'String',strkat('Running Trial: \n','Paradigm: \t \t  ',ControlParadigmList{ThisParadigm},'\n Trial: \t \t ',mat2str(sz(1)+1)))
       
                
            end
            
        end
        
        w=str2num(get(SamplingRateControl,'String'));
        if isempty(w)
            error('Sampling Rate not defined!')
        end
        T= length(ControlParadigm(ThisParadigm).Outputs)/w; % duration of trial, for this trial
        % create session
        clear s
        s = daq.createSession('ni');
        s.DurationInSeconds = T;
        s.NotifyWhenDataAvailableExceeds = w/10; % 10Hz
        s.Rate = w; % sampling rate, user defined.
         
        % show the traces as we acquire them on the scope
        figure(scope_fig)
        
        % update scope_plot_data
        ScopeHandles = []; % axis handles for each sub plot in scope
        rows = ceil(length(get(PlotInputs,'Value'))/2);
        ScopeThese = get(PlotInputs,'Value');
        scope_plot_data = NaN(length(UsedInputChannels),T*w);
        
        ti = 1;
        for i = ScopeThese
            ScopeHandles(i) = subplot(2,rows,ti); ti = ti+1;
            set(ScopeHandles(i),'XLim',[0 T]), hold on
            plotname=strcat(InputChannels{UsedInputChannels(i)},'-',InputChannelNames{UsedInputChannels(i)});
            plotname = strrep(plotname,'_','-');
            title(plotname)
        end
        clear i
         
        % add the analogue input channels
        TheseChannels=InputChannels(UsedInputChannels);
        for i = 1:length(TheseChannels)
            s.addAnalogInputChannel('Dev1',InputChannels{UsedInputChannels(i)}, 'Voltage');
        end
        clear i

        % add the analogue output channels
        TheseChannels=OutputChannels(UsedOutputChannels);
        for i = 1:length(TheseChannels)
             s.addAnalogOutputChannel('Dev1',OutputChannels{UsedOutputChannels(i)}, 'Voltage');
        end
        clear i

        % add the digital output channels
        TheseChannels=DigitalOutputChannels(UsedDigitalOutputChannels);
        for i = 1:length(TheseChannels)
             s.addDigitalChannel('Dev1',DigitalOutputChannels{UsedDigitalOutputChannels(i)}, 'OutputOnly');
        end
        clear i

        % configure listener to plot data on the scopes 
        lh = s.addlistener('DataAvailable',@PlotCallback);
        
        % configure listener to log data
        %lhWrite = s.addlistener('DataAvailable',@(src, event)logData(src, event, fid1));
        
        % queue data        
        s.queueOutputData(ControlParadigm(ThisParadigm).Outputs');
        
        % log the timestamp
        ts = size(timestamps);
        timestamps(1,ts(2)+1)=ThisParadigm; % paradigm number
        timestamps(2,ts(2)+1)=Trials(ThisParadigm); % trial number
        timestamps(3,ts(2)+1)=(now); % time
        
        % read and write
        trial_running = T*10;
        try
            s.startForeground();
        catch
            % probably because the hardware is reserved.
            close all
            errordlg('Kontroller could not start the task. This is probably because the hardware is reserved. You need to restart Kontroller. Sorry about that. Type "return" and hit enter to restart.')
            clear all
            exit
            
            
        end
        ProcessTrialData;

        set(ConfigureInputChannelButton,'Enable','on');
        set(ConfigureOutputChannelButton,'Enable','on');
        set(ConfigureControlSignalsButton,'Enable','on');
        set(RunProgramButton,'Enable','on');
        set(PauseProgramButton,'Enable','on');
        set(StartScopes,'Enable','on');
        set(MetadataButton,'Enable','on');
        set(ManualControlButton,'Enable','on');
        set(FileNameSelect,'Enable','on');
        set(SaveControlParadigmsButton,'Enable','on');
        set(RemoveControlParadigmsButton,'Enable','on');



    end

%% process data == this function is called when the trial finishes running
    function [] = ProcessTrialData(eo,ed)
        % delete listeners
        delete(lh)
        
        % check if data needs to be logged
        if isempty(SaveToFile) && gui == 1
            set(RunTrialButton,'enable','on','String','RUN w/o saving');
            return
        end
        
        % combine data and label correctly
        thisdata=scope_plot_data;
        if gui
            ThisParadigm= (get(ParadigmListDisplay,'Value'));
        else
            ThisParadigm = RunTheseParadigms(gi);
        end
        % check if data exists
        if isempty(data)
            % create it          
            for i = 1:length(UsedInputChannels)
                if  ~strcmp(InputChannelNames{UsedInputChannels(i)},'Ground')               
                    eval( strcat('data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},'=thisdata(',mat2str(i),',:);'));
                end
            end
            clear i

        else
            % some data already exists, need to append
            % find the correct pradigm
            if length(data) < ThisParadigm
                % first trial in this paradigm
                for i = 1:length(UsedInputChannels)
                    if  ~strcmp(InputChannelNames{UsedInputChannels(i)},'Ground')
                        eval(strcat('data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},'=[];'))
                    end
                end
            end

            for i = 1:length(UsedInputChannels)
                if  ~strcmp(InputChannelNames{UsedInputChannels(i)},'Ground')
                    eval( strcat('data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},'=vertcat(data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},',thisdata(',mat2str(i),',:));'))
            
                end
            end

        end
            
        % save data to file
        if gui
            SamplingRate= str2double(get(SamplingRateControl,'String'));
        end
        
        if gui
            temp = OutputChannelNames;
            OutputChannelNames = {OutputChannelNames{UsedOutputChannels} DigitalOutputChannelNames{UsedDigitalOutputChannels}};
            save(strcat('C:\data\',SaveToFile),'data','ControlParadigm','metadata','OutputChannelNames','SamplingRate','timestamps');       
        
            OutputChannelNames = temp; clear temp
            set(RunTrialButton,'Enable','on','String','RUN and SAVE');      
            set(Konsole,'String',strkat('Trial ',mat2str(Trials(ThisParadigm)),'/Paradigm ',mat2str(ThisParadigm),' completed.'));
        end
        % check to make sure that the session has stopped
        if s.IsRunning
            s.stop;
        end
        % check if there is a programme running, and handle it approproately 
        if programme_running
            % continue with the flow
            RunProgram;
        end
        
    end

%% save control paradigms
    function [] = SaveControlParadigms(eo,ed)
        temp=strcat(datestr(now,'yyyy_mm_dd'),'_Kontroller_paradigm_.mat');
        ControlParadigmSaveToFile=uiputfile(temp);
        save(ControlParadigmSaveToFile,'ControlParadigm');
    end

%% load saved control paradigms
    function [] = LoadSavedParadigms(eo,ed)
        [FileName,PathName] = uigetfile('*_Kontroller_paradigm*');
        temp=load(strcat(PathName,FileName));

        % check that this Control PAradigm has the same number of outputs as there are output channels
        [nol,~]=size(temp.ControlParadigm(1).Outputs);
        if nol == length(UsedOutputChannels) + length(UsedDigitalOutputChannels)
            % alles OK
        else
            % ouch
            
            errordlg('Error: The Paradigm you tried to load doesnt have the same number of outputs as the number of outputs currently configured. Either load a new Control Paradigm, or change the number of OutputChannels to match this paradigm.','Kontroller cannot do this.')
            return
        end 

        ControlParadigm=temp.ControlParadigm;
        clear temp
        % now update the list
        ControlParadigmList = {};
        for i = 1:length(ControlParadigm)
            ControlParadigmList = [ControlParadigmList ControlParadigm(i).Name];
        end
        set(ParadigmListDisplay,'String',ControlParadigmList)
        
        % update Trial count
        Trials = zeros(1,length(ControlParadigmList));
        set(Konsole,'String','Controls have been configured. ')
        
        % update run button
        if isempty(SaveToFile)
            set(RunTrialButton,'enable','on','String','RUN w/o saving','BackgroundColor',[0.9 0.1 0.1]);
        else
            set(RunTrialButton,'enable','on','String','RUN and SAVE','BackgroundColor',[0.1 0.9 0.1]);
        end
        delete(fcs)
    end

%% metadata callback
    function [] = MetadataCallback(eo,ed)
        % open the editor
        mef = figure('Position',[60 50 450 400],'Toolbar','none','Menubar','none','Name','Metadata Editor','NumberTitle','off','Resize','off');
        uicontrol(mef,'Style','Text','String','Add or modify metadata using standard MATLAB syntax, one variable at a time, below:','Position',[5 340 440 50],'HorizontalAlignment','left')
        MetadataTextControl = uicontrol(mef,'Style', 'edit', 'String','','Position',[5 285 440 40],'HorizontalAlignment','left','Callback',@AddMetadata);
        MetadataTextDisplay = uicontrol(mef,'Style','Text','String',metadatatext,'Position',[5 5 440 270]);
        
    end

%% metadata editor callback
    function [] = AddMetadata(eo,ed)        
        % evaluate it
        eval(strcat('metadata.',get(MetadataTextControl,'String')));
        % rebuild display cell string
        metadatatext = [];
        fn = fieldnames(metadata);
        for i = 1:length(fn)
            metadatatext{i} = strcat(fn{i},' : ',mat2str(getfield(metadata,fn{i})));
        end
        set(MetadataTextDisplay,'String',metadatatext);
        set(MetadataTextControl,'String','');
        
    end

%% clean up when quitting Kontroller
    function [] = QuitKontrollerCallback(eo,ed)
       selection = questdlg('Are you sure you want to quit Kontroller?','Confirm quit.','Yes','No','Yes'); 
       switch selection, 
          case 'Yes',
              try
                delete(scope_fig)
              catch
              end
              try
                delete(mef)
              catch
              end
              try
                   delete(f1);
              catch
              end
              try
                    delete(f2);
              catch
              end
              try
                    delete(f3);
              catch
              end
              try
                    delete(f4);
              catch
              end
              try
                    delete(mef);
              catch
              end
              try
                    delete(ViewParadigmFig);
              catch
              end
              try
                    delete(fcs);
              catch
              end
          case 'No'
          return 
       end
    end

%% clean up when quitting Manual Control
    function [] = QuitManualControlCallback(eo,ed)
        % stop session
        try
            s.stop;
            delete(lh)
            delete(lhMC)
        catch
        end
        
        delete(gcf)
        scopes_running=0;

    end

%% on closing output config wiindows
    function  [] = QuitConfigOutputsCallback(eo,ed)
        % close both windows together
        try
            delete(f3);
        end
        try
            delete(f4);
        end
    end

%% remove control paradigms

    function [] = RemoveControlParadigms(eo,ed)
        if ~isempty(ControlParadigmList)
            removethese = get(ParadigmListDisplay,'Value');
            
             
            % remove them from the ControlParadigm list
            ControlParadigmList(removethese) = [];
            
            % remove them from the display list
            set(ParadigmListDisplay,'Value',1)
            set(ParadigmListDisplay,'String',ControlParadigmList);
            % remove them from the actual control paradigm data structure
            ControlParadigm(removethese) = [];
            
        else
            % do nothing for now
        end
        
    end

%% Compute Epochs

    function [] = ComputeEpochs(eo,ed)
        ThisParadigm =  (get(ParadigmListDisplay,'Value'));
        TheseDigitalOutputs = [];
        TheseDigitalOutputs=ControlParadigm(ThisParadigm).Outputs(length(UsedOutputChannels)+1:length([UsedOutputChannels UsedDigitalOutputChannels]),:);
        sz = size(TheseDigitalOutputs);
        Epochs = zeros(1,sz(2));
        for si = 1:sz(1)
            TheseDigitalOutputs(si,:) = TheseDigitalOutputs(si,:).*(2^si-1);
        end
        Epochs = sum(TheseDigitalOutputs);
        
        % compress epochs
        ue = unique(Epochs);
        for si = 1:length(unique(Epochs))
            Epochs(Epochs == ue(si)) = 1e4+si;
        end
        Epochs = Epochs-1e4;
        
        
    end

end