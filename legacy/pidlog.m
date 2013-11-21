% pidlog.m
% this creates a log file of when the pid has been turned on and off
% usage:
% pidlog(1) means the pid has been turned on now
% pidlog(0) means the pid has been turned off now
function [] = pidlog(state)
% load pid log file 
load pidlogfile.mat
% this is a matrix with two columns: the first is the timestamp, and the
% second is the state change
s = size(pidlogfile);
s = s(1);
switch state
    case 0
        pidlogfile = [pidlogfile; [now 0]];
        disp('PID is off. This has been logged')
    case 1
        pidlogfile = [pidlogfile; [now 1]];
        disp('PID is on. This has been logged')
end

% close and save
save('pidlogfile.mat','pidlogfile')
