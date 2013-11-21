% runs the stirrer for a specified amount of time
function [] = stir(t_end) 
s = daq.createSession('ni');
s.addDigitalChannel('Dev1', 'Port0/Line11', 'OutputOnly')
tic;
t=toc;
while t < t_end
    s.outputSingleScan (1);
    pause(0.17)
    s.outputSingleScan (0);
    pause(0.1)
    t=toc;
end

% stop it
s.outputSingleScan(1)