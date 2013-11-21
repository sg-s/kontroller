% runs the stirrer for a specified amount of time
function [] = stir(t_end) 
clear s
warning off
stirsession = daq.createSession('ni');
stirsession.addDigitalChannel('Dev1', 'Port0/Line11', 'OutputOnly');
tic;
t=toc;
while t < t_end
    stirsession.outputSingleScan (1);
    pause(0.25)
    stirsession.outputSingleScan (0);
    pause(0.1)
    t=toc;
end

% stop it
stirsession.outputSingleScan(1)
clear t
clear s
warning on