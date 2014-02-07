% makes MFC dilutions signals
% input dilution is ratio of MFC1 flow to MFC2 flow
function [ControlParadigm] = MakeMFCDilutionSignals(dilutions,varargin)

% defaults
MFC1_Max = 500; % ml/min
MFC2_Max = 500; % ml/min
MFC3_Max = 1000; % ml/min
T_on = 20;
T_off = 3;
T_purge = 0;
w =1000;
FlowRate = 300; % in each arm of the device. 

% evaluate optional arguments
for i = 2:nargin
    eval(varargin{i-1});
end

% validate arguments
if FlowRate > 333
    error('Cant do this flowrate. too high')
end

T = T_on + T_off;
ControlParadigm(1).Name = 'generic';
ControlParadigm(1).Outputs = zeros(3,T*w);

for i = 1:length(dilutions)
    ControlParadigm(i).Outputs = zeros(3,T*w);
    if dilutions(i)  > 1
        % FLIP IT
        thisdil = 1/(dilutions(i)+1);
        FlowRate2 = FlowRate*thisdil;
        FlowRate1 = FlowRate*(1-thisdil);

        ControlParadigm(i).Outputs(1,1:T_on*w) = 5*FlowRate1*ones(1,T_on*w)/MFC1_Max;
        ControlParadigm(i).Outputs(2,1:T_on*w) = 5*FlowRate2*ones(1,T_on*w)/MFC2_Max;
        
        % don't forget 3
        ControlParadigm(i).Outputs(3,1:T_on*w) = 5*FlowRate*3*ones(1,T_on*w)/MFC3_Max;
        ControlParadigm(i).Name = strkat(mat2str(dilutions(i)),'-1');
    else
    	thisdil = 1/(round(1/dilutions(i))+1);
        denom = round(1/dilutions(i));
    	FlowRate1 = FlowRate*thisdil;
        FlowRate2 = FlowRate*(1-thisdil);

        ControlParadigm(i).Outputs(1,1:T_on*w) = 5*FlowRate1*ones(1,T_on*w)/MFC1_Max;
        ControlParadigm(i).Outputs(2,1:T_on*w) = 5*FlowRate2*ones(1,T_on*w)/MFC2_Max;

        % don't forget 3
        ControlParadigm(i).Outputs(3,1:T_on*w) = 5*FlowRate*3*ones(1,T_on*w)/MFC3_Max;
        ControlParadigm(i).Name = strkat('1-',mat2str(denom));
    end
    
    % make sure nothing over 5 volts is delivered
    if max(max(ControlParadigm(i).Outputs)) > 5
        error('Dangerously high voltage! I cant safely make this.')
    end
end

