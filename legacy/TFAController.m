% TFAController.m
% This m file creates a GUI which does the following:
% continuously show data streams on some channels (a multi-oscilloscope)
% show, record and save triggered data on command
% handle trial numbering, etc.

function TFAController()
%% make the GUI
clc
f1 = figure('Position',[60 50 450 600],'Toolbar','none','Menubar','none','Name','TFAController','NumberTitle','off','Resize','off');
disp('TFA Controller starting...')
ConfigureInputChannelButton = uicontrol('Position',[15 540 140 50],'Style','pushbutton','Enable','on','String','Configure Inputs','FontSize',12,'Callback',@ConfigureInputChannels);
ConfigureOutputChannelButton = uicontrol('Position',[160 540 140 50],'Style','pushbutton','Enable','on','String','Configure Outputs','FontSize',12,'Callback',@ConfigureOutputChannels);
ConfigureControlSignalsButton = uicontrol('Position',[305 540 140 50],'Style','pushbutton','Enable','off','String','Configure Control','FontSize',12,'Callback',@ConfigureControlSignals);
InputChannelsPanel = uipanel('Title','Input Channels','FontSize',12,'units','pixels','pos',[15 330 240 200]);
PlotInputsList = {};
PlotOutputsList = {};
PlotInputs = uicontrol(InputChannelsPanel,'Position',[3 3 230 170],'Style','listbox','Min',0,'Max',2,'String',PlotInputsList,'FontSize',11);
OutputChannelsPanel = uipanel('Title','Output Channels','FontSize',12,'units','pixels','pos',[265 330 170 130]);
PlotOutputs = uicontrol(OutputChannelsPanel,'Position',[3 3 165 100],'Style','listbox','Min',0,'Max',2,'String',PlotOutputsList,'FontSize',11);

ControlParadigmList = {}; % stores a list of different control paradigm names. e.g., control, test, odour1, etc.
ParadigmPanel = uipanel('Title','Control Paradigms','FontSize',12,'units','pixels','pos',[15 30 170 130]);
ParadigmListDisplay = uicontrol(ParadigmPanel,'Position',[3 3 155 105],'Style','listbox','Enable','on','String',ControlParadigmList,'FontSize',12,'Min',0,'Max',1);
ControlParadigm = []; % stores the actual control signals for the different control paradigm

SamplingRateControl = uicontrol(f1,'Position',[113 5 70 20],'Style','edit');
uicontrol(f1,'Position',[20 5 70 20],'Style','text','String','Sampling Rate');
RunTrialButton = uicontrol(f1,'Position',[320 5 110 50],'Enable','off','Style','pushbutton','String','RUN','Callback',@RunTrial);

FileNameDisplay = uicontrol(f1,'Position',[200,60,230,50],'Style','text','String','No destination file selected');
FileNameSelect = uicontrol(f1,'Position',[200,5,100,50],'Style','pushbutton','String','Write to...','Callback',@SelectDestinationCallback);

AutomatePanel = uipanel('Title','Automate','FontSize',12,'units','pixels','pos',[205 120 230 200]);
uicontrol(AutomatePanel,'Style','text','FontSize',8,'String','Repeat all paradigms','Position',[1 120 100 50])
uicontrol(AutomatePanel,'Style','text','FontSize',8,'String','times','Position',[150 110 50 50])
RepeatNTimesControl = uicontrol(AutomatePanel,'Style','edit','FontSize',8,'String','1','Position',[110 140 30 30]);
RunProgramButton = uicontrol(AutomatePanel,'Position',[4 5 110 30],'Enable','on','Style','pushbutton','String','RUN PROGRAM','Callback',@RunProgram);


StartScopes = uicontrol(f1,'Position',[260 465 150 50],'Style','pushbutton','Enable','off','String','Start Scopes','FontSize',12,'Callback',@ScopeCallback);
scope_fig = figure('Position',[540 100 700 550],'Toolbar','none','Menubar','none','Name','Oscilloscope','NumberTitle','off','Resize','off'); hold on; 
ScopeHandles = [];
ParadigmNameUI = [];
ControlHandles= [];
VarNames = [];
SaveToFile= [];
data = [];
scope_plot_data = [];
scopes_running = 0;
ss=[];
s=[]; % this is the session ID
lh = []; % listener ID

%% figure out DAQ characteristics
d = daq.getDevices(); 
OutputChannels =  d.Subsystems(2).ChannelNames;
nOutputChannels = length(OutputChannels);
InputChannels =  d.Subsystems(1).ChannelNames;
nInputChannels = length(InputChannels);
li = []; ri = []; lo = []; ro = [];
UsedInputChannels = [];
InputChannelNames = {}; % this is the user defined names
UsedOutputChannels = [];
OutputChannelNames = {}; % this is the user defined names
% load saved configs...inputs
if ~isempty(dir('TFAIConfig.mat'))
    disp('Loading saved input config files...')
    load('TFAIConfig.mat','UsedInputChannels','InputChannelNames')
    PlotInputsList = InputChannelNames(UsedInputChannels);
     set(PlotInputs,'String',PlotInputsList)
     if ~isempty(UsedInputChannels)
         set(StartScopes,'Enable','on')
     else 
         set(StartScopes,'Enable','off')
     end
     disp('DONE')
end
% load saved configs..outputs
if ~isempty(dir('TFAOConfig.mat'))
    disp('Loading saved output config files...')
    load('TFAOConfig.mat','UsedOutputChannels','OutputChannelNames')
     if ~isempty(UsedOutputChannels)
         set(ConfigureControlSignalsButton,'Enable','on')
     else 
         set(ConfigureControlSignalsButton,'Enable','off')
     end
     % update PlotOutputsList
     PlotOutputsList = OutputChannelNames(UsedOutputChannels);
     set(PlotOutputs,'String',PlotOutputsList);
     disp('DONE')
end

%% configure inputs
    function [] =ConfigureInputChannels(eo,ed)
        % load saved configs      
        n = nInputChannels;
        Height = 600;
        f2 = figure('Position',[60 50 450 Height],'Toolbar','none','Menubar','none','Name','Label Channels','NumberTitle','off');
        a = axes; hold on
        set(a,'Visible','off');
        if floor(n/2)*2 == n
            % even n
            nspacing = Height/(n/2);
            % generate UIcontrol edit boxes
            for i = 1:n/2  % left side
                if ismember(i,UsedInputChannels)
                    li(i) = uicontrol(f2,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','String',InputChannelNames{i},'FontSize',16,'Callback',@InputConfigCallback);
                else
                    li(i) = uicontrol(f2,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','FontSize',16,'Callback',@InputConfigCallback);
                end
                uicontrol(f2,'Position',[160 Height-i*nspacing 50 20],'Style', 'text','String',InputChannels{i},'FontSize',12);
            end
            for i = 1:n/2  % right side
                if ismember(n/2+i,UsedInputChannels)
                    ri(i) = uicontrol(f2,'Position',[300 Height-i*nspacing 100 20],'Style', 'edit','String',InputChannelNames{n/2+i},'FontSize',16,'Callback',@InputConfigCallback);
                else
                    ri(i) = uicontrol(f2,'Position',[300 Height-i*nspacing 100 20],'Style', 'edit','FontSize',16,'Callback',@InputConfigCallback);
                end
                uicontrol(f2,'Position',[220 Height-i*nspacing 50 20],'Style', 'text','String',InputChannels{n/2+i},'FontSize',12);
            end
            
        else
            error('Odd number of channels, cannot handle this')
        end
    
    end

%% configure outputs
    function [] =ConfigureOutputChannels(eo,ed)
        n = nOutputChannels;
        Height = 600;
        f3 = figure('Position',[60 50 450 Height],'Toolbar','none','Menubar','none','Name','Label Output Channels','NumberTitle','off');
        a = axes; hold on
        set(a,'Visible','off');
        if floor(n/2)*2 == n
            % even n
            nspacing = Height/(n/2+1);
            % generate UIcontrol edit boxes
            for i = 1:n/2  % left side
                if ismember(i,UsedOutputChannels)
                    lo(i) = uicontrol(f3,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','String',OutputChannelNames{i},'FontSize',16,'Callback',@OutputConfigCallback);
                else
                    lo(i) = uicontrol(f3,'Position',[40 Height-i*nspacing 100 20],'Style', 'edit','FontSize',16,'Callback',@OutputConfigCallback);
                end
                uicontrol(f3,'Position',[160 Height-i*nspacing 50 20],'Style', 'text','String',OutputChannels{i},'FontSize',12);
            end
            for i = 1:n/2  % right side
                if ismember(n/2+i,UsedOutputChannels)
                    
                    ro(i) = uicontrol(f3,'Position',[300 Height-i*nspacing 100 20],'Style', 'edit','String',OutputChannelNames{n/2+i},'FontSize',16,'Callback',@OutputConfigCallback);
                else
                    ro(i) = uicontrol(f3,'Position',[300 Height-i*nspacing 100 20],'Style', 'edit','FontSize',16,'Callback',@OutputConfigCallback);
                end
                uicontrol(f3,'Position',[220 Height-i*nspacing 50 20],'Style', 'text','String',OutputChannels{n/2+i},'FontSize',12);
            end
            
        else
            error('Odd number of channels, cannot handle this')
        end
    
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
              end
         end
         % then scan right
         for i = 1:n/2
              if isempty(strmatch(get(ri(i),'String'),InputChannels))
                  % use this channel
                  UsedInputChannels = [UsedInputChannels n/2+i];
                  InputChannelNames{n/2+i} = get(ri(i),'String');
              end
         end
         
         % update the input channel list
         PlotInputsList = InputChannelNames(UsedInputChannels);
         set(PlotInputs,'String',PlotInputsList)
         if ~isempty(UsedInputChannels)
             set(StartScopes,'Enable','on')
             
         else 
             set(StartScopes,'Enable','off')
         end
         % save Input Channel Names for persisitent config
         save('TFAIConfig.mat','InputChannelNames','UsedInputChannels');
        
    end

%% output config callback
function [] = OutputConfigCallback(eo,ed)
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
         % then scan right
         for i = 1:n/2
              if isempty(strmatch(get(ro(i),'String'),OutputChannels))
                  % use this channel
                  UsedOutputChannels = [UsedOutputChannels n/2+i];
                  OutputChannelNames{n/2+i} = get(ro(i),'String');
              end
         end
         
         % update the output channel control signal config
         if ~isempty(UsedOutputChannels)
             set(ConfigureControlSignalsButton,'Enable','on')
             
         else 
             set(ConfigureControlSignalsButton,'Enable','off')
         end
         PlotOutputsList = OutputChannelNames(UsedOutputChannels);
         set(PlotOutputs,'String',PlotOutputsList)
         % save Input Channel Names for persisitent config
         save('TFAOConfig.mat','OutputChannelNames','UsedOutputChannels');
        
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
                w = 1000; % 1kHz sampling     
                % create session
                s = daq.createSession('ni');
                s.IsContinuous = true;
                s.NotifyWhenDataAvailableExceeds = 100; % 10Hz
                % update scope_plot_data
                scope_plot_data = NaN(length(get(PlotInputs,'Value')),5000); % 5 s of  data in each channel
                ScopeHandles = []; % axis handles for each sub plot in scope
                rows = ceil(length(get(PlotInputs,'Value'))/2);
                for i = 1:length(get(PlotInputs,'Value'))
                    ScopeHandles(i) = subplot(2,rows,i);
                    set(ScopeHandles(i),'XLim',[0 5000]), hold off
                    title( strcat(InputChannels{UsedInputChannels(i)},' -- ',InputChannelNames{UsedInputChannels(i)}))
                    s.addAnalogInputChannel('Dev1',InputChannels{UsedInputChannels(i)}, 'Voltage'); % add channel
                end
                s.Rate = w; 
                lh = s.addlistener('DataAvailable',@PlotCallback);
                
                
                % relabel scopes button
                set(StartScopes,'String','Stop Scopes');
                
                s.startBackground();
                scopes_running = 1;
   
            end
       
        end   
    end

%% update scopes callback
    function [] = PlotCallback(src,event)
        for i = 1:length(ScopeHandles)
            keyboard
            scope_plot_data(i,:)=[scope_plot_data(i,length(event.Data)+1:end) event.Data(:,i)'];
            plot(ScopeHandles(i),scope_plot_data(i,:));
        end
    end

%% configure control signals
    function [] = ConfigureControlSignals(eo,ed)
        no = length(UsedOutputChannels);
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
        
        var(badvar) = []; clear badvar
        if length(var) >= no
            % assemble names into a cell array
            VarNames = {};
            for i = 1:length(var)
                VarNames{i} = var(i).name;
            end
        else
            error('You do not have enough variables in the workspace to configure the control signals. Either create them or reconfigure your outputs.')
        end
        fcs= figure('Position',[200 200 450 Height],'Toolbar','none','Menubar','none','Name','Select Control Signals','NumberTitle','off');
        ControlHandles = [];
        % get name of control pradigm
        ParadigmNameUI=uicontrol(fcs,'Position',[(450-340)/2 Height-30 340 24],'Style', 'edit','String','Enter Name of Control Paradigm','FontSize',16);
        for i = 1:no
            ControlHandles(i) = uicontrol(fcs,'Position',[150 10+i*100 150 50],'Style','popupmenu','Enable','on','String',VarNames,'FontSize',12);
            uicontrol(fcs,'Position',[30 30+i*100 100 30],'Style','text','String',OutputChannels{UsedOutputChannels(i)},'FontSize',12);
            uicontrol(fcs,'Position',[320 30+i*100 100 30],'Style','text','String',OutputChannelNames{UsedOutputChannels(i)},'FontSize',12);
        
        end
        % button to save and close
        uicontrol(fcs,'Position',[370 30 60 30],'Style','pushbutton','String','DONE','FontSize',12,'Callback',@ConfigureControlCallback);
        
    end

%% configure control callback
    function [] = ConfigureControlCallback(eo,ed)
        % assume everything is OK, and make a paradigm
        ControlParadigm(length(ControlParadigm)+1).Name= get(ParadigmNameUI,'String');
        thisp = length(ControlParadigm);
        % and now fill in the values
        for i = 1: length(UsedOutputChannels);
            ControlParadigm(thisp).Outputs(i,:)=evalin('base',cell2mat(VarNames(get(ControlHandles(i),'Value'))));
        end
        % update the paradigm list
        ControlParadigmList = [ControlParadigmList get(ParadigmNameUI,'String')];
        set(ParadigmListDisplay,'String',ControlParadigmList)
    end
%% select destintion callback
    function [] = SelectDestinationCallback(eo,ed)
        temp=strcat(datestr(now,'yyyy_mm_dd'),'_XXs_TFA_GINXXX_m1fly_odour_300.mat');
        SaveToFile=uiputfile(strcat('C:\data\',temp));
        % activate the run button
        set(RunTrialButton,'enable','on');
        % update display
        set(FileNameDisplay,'String',SaveToFile);
    end
%% run programmme
    function [] = RunProgram(eo,ed)
        for np = 1:length(get(ParadigmListDisplay,'String'))
            set(ParadigmListDisplay,'Value',np);
            ntrials= str2num(get(RepeatNTimesControl,'String'));
            for nrep = 1:ntrials
                RunTrial;
            end 
        end
    end

%% run trial
    function [] = RunTrial(eo,ed)        
        set(RunTrialButton,'Enable','off')
        % figure out which pradigm to run
        ThisParadigm= (get(ParadigmListDisplay,'Value'));
         
        % make afigure to show the traces as we acquire them
        figure(scope_fig)
            w=str2num(get(SamplingRateControl,'String'));
            if isempty(w)
                error('Sampling Rate not defined!')
            end
            T= length(ControlParadigm(ThisParadigm).Outputs)/w;  
            % create session
            s = daq.createSession('ni');
            s.DurationInSeconds = T;
            s.Rate = w; % sampling rate, user defined.
            TheseChannels=InputChannels(UsedInputChannels);
            for i = 1:length(TheseChannels)
                s.addAnalogInputChannel('Dev1',InputChannels{UsedInputChannels(i)}, 'Voltage');
            end
            TheseChannels=OutputChannels(UsedOutputChannels);
            for i = 1:length(TheseChannels)
                 s.addAnalogOutputChannel('Dev1',OutputChannels{UsedOutputChannels(i)}, 'Voltage');
            end
            
            % queue data
            s.queueOutputData(ControlParadigm(ThisParadigm).Outputs');
            
            
            %% read and write
            disp('Running trial...')
            thisdata=s.startForeground();
            thisdata=thisdata';
            disp('DONE')
            
            % combine data and label correctly
            % check if data exists
            if isempty(data)
                % create it          
                for i = 1:length(UsedInputChannels)
                    eval( strcat('data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},'=thisdata(',mat2str(i),',:);'));
                end
            else
                % some data already exists, need to append
                % find the correct pradigm
                if length(data) < ThisParadigm
                    for i = 1:length(UsedInputChannels)
                        eval(strcat('data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},'=[];'))
                    end
                end
                
                for i = 1:length(UsedInputChannels)
                    
                    eval( strcat('data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},'=vertcat(data(ThisParadigm).',InputChannelNames{UsedInputChannels(i)},',thisdata(',mat2str(i),',:));'))
                end
            
            end
            
            % save data to file
            save(strcat('C:\data\',SaveToFile),'data','ControlParadigm');
            
      set(RunTrialButton,'Enable','on')      
    end
end