% TFAcontroller.m
% this little script will read something and write something to the NIDaq
% simulatenously
% hardware reality:
% ao0 is connected to ai20 directly. 
% as a test, lets read WBF values, and write signals to the MFCs. 

%% startups checks
d = daq.getDevices;
if ~strmatch(d.ID,'Dev1')
    error('Never seen this device before.')
end


%% basic parameters for stimulation, etc.
w = 1000; % sampling rate
AirOn = 1;
AirOff = 2;
FlowRate = 300;

% scopes
f1 = figure; hold on;
a1 = subplot(2,2,1);  hold on, title('Channel 1')
a2 = subplot(2,2,2);  hold on, title('Channel 2')
a3 = subplot(2,2,3);  hold on
a4 = subplot(2,2,4);  hold on

set(a1,'YLim',[-0.05 5], 'XLim',[0 5]), hold on
set(a2,'YLim',[-0.05 5], 'XLim',[0 5]), hold on
set(a3,'YLim',[-0.05 5], 'XLim',[0 5]), hold on
set(a4,'YLim',[-0.05 5], 'XLim',[0 5]), hold on

%% create session
s = daq.createSession('ni');
s.IsContinuous = true;
s.addAnalogInputChannel('Dev1','ai20', 'Voltage'); % WBF
s.addAnalogInputChannel('Dev1','ai2', 'Voltage'); % WBF
s.Rate = w; % 10kHz sampling





%% listener to dynamically plot
lh = s.addlistener('DataAvailable',@PlotCallback);
s.NotifyWhenDataAvailableExceeds = 1000; % 10Hz


%% read and write
disp('Running trial...')
s.startBackground();
disp('DONE')
%% clean up
delete(lh)


function [] = PlotCallback(src,event)
    plot(a1,event.TimeStamps, event.Data(:,1));
    plot(a2,event.TimeStamps, event.Data(:,2));
end


