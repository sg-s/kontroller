% make dilution controls 2.m
% makes a long air step, with 1-second long pulse of the valve.
% this is to check that airspeed are OK
% there are three MFCs, connected as follows:
% AO1       small MFC       MFC 1     this feeds into odour bottle.
% AO2       small MFC       MFC 2     this dilutes odour with air
% AO3       large MFC       MFC 2     this provides clean air for the valve; never mixes with odour         
%%
function [ControlParadigm] = make_dilution_controls2(TotalFlow,npulses,CorrectionFactor)

sr = 1000; % sampling rate
T_purge = 2; % this is the time when the MFC is open to 1/5 of its max reading
T_flush = 10; % this is the time when the MFC is open to setpoint, but air is off
T_delay = 5; % this is the delay for the big MFC so that it only opens when the small MFC is open
T_off = 3; % how long should everything shut down in the end?
MaxFlow_small = 1000; % max flow of small MFC
MaxFlow_large = 5000; % max flow of big MFC
T_pulse=2;
T_padding = 4;
T = npulses*(2*T_padding+T_pulse); % this is the length of time during which the pulse +padding happens

%% make the air, blank and pulse
Air = [zeros(1,(T_flush+T_purge)*sr) ones(1,T*sr) zeros(1,T_off*sr)];
Blank = 0*Air;
Pulse = zeros(1,(T_flush+T_purge)*sr);
for i = 1:npulses
    Pulse = [Pulse zeros(1,T_padding*sr) ones(1,T_pulse*sr) zeros(1,T_padding*sr)];
end
Pulse=[Pulse zeros(1,T_off*sr)];
% add some pre-pulses
Pulse(10500:11000)=1;
Pulse(9500:10000)=1;
Pulse(8500:9000) = 1;
%% make the vectors--dilutor<odour
dilution_ranges = [Inf 9 4 1]; % (all these numbers):1
dr = 1./(dilution_ranges+1); % dilution ratios
for i = 1:length(dr)
    setpoint = CorrectionFactor(i)*5*(1-dr(i))*TotalFlow/MaxFlow_small; 
    airpoint = CorrectionFactor(i)*5*(dr(i))*TotalFlow/MaxFlow_small;
    
    cleanairpoint = 3*5*TotalFlow/MaxFlow_large;
    
    % MFC 1
    flushpoint = max(1,setpoint); % to initially open the MFC
    MFC_1 = [flushpoint*ones(1,T_purge*sr) setpoint*ones(1,(T_flush+T)*sr) zeros(1,T_off*sr)];
    
    % MFC 2
    if i == 1
        MFC_2 = 0*[flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T)*sr) zeros(1,T_off*sr)];
    else
        MFC_2 = [flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T)*sr) zeros(1,T_off*sr)];
    end
    
    
    % MFC 3
    MFC_3 = [zeros(1,T_delay*sr) cleanairpoint*ones(1,(T_purge+T_flush+T-T_delay)*sr) zeros(1,T_off*sr)];
    
    
    ControlParadigm(i).Outputs = [MFC_1; MFC_2; MFC_3 ; Air; Blank; Pulse];
    ControlParadigm(i).Name = strcat('Dilution_',mat2str(dilution_ranges(i)),'_1');
    
end
ti = length(ControlParadigm);

%% make the vectors--dilutor>odour
dilution_ranges = [2 3 5 9 19 39]; % 1:(all these numbers)
dr = 1./(dilution_ranges+1); % dilution ratios
for ci = ti+1:ti+length(dr)
    i = ci - ti;
    setpoint = CorrectionFactor(ci)*5*dr(i)*TotalFlow/MaxFlow_small; 
    airpoint = CorrectionFactor(ci)*5*(1-dr(i))*TotalFlow/MaxFlow_small;
    
    cleanairpoint = 3*5*TotalFlow/MaxFlow_large;
    
    % MFC 1
    flushpoint = max(1,setpoint); % to initially open the MFC
    MFC_1 = [flushpoint*ones(1,T_purge*sr) setpoint*ones(1,(T_flush+T)*sr) zeros(1,T_off*sr)];
    
    % MFC 2
    MFC_2 = [flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T)*sr) zeros(1,T_off*sr)];
    
    % MFC 3
    MFC_3 = [zeros(1,T_delay*sr) cleanairpoint*ones(1,(T_purge+T_flush+T-T_delay)*sr) zeros(1,T_off*sr)];
    
    
    ControlParadigm(ci).Outputs = [MFC_1; MFC_2; MFC_3 ; Air; Blank; Pulse];
    ControlParadigm(ci).Name = strcat('Dilution_1_',mat2str(dilution_ranges(i)));
end

%% then make one more for the control switch
ci = length(ControlParadigm) + 1;
% MFC 2
airpoint = 5*TotalFlow/MaxFlow_small;
cleanairpoint = 3*5*TotalFlow/MaxFlow_large;
MFC_2 = [flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T)*sr) zeros(1,T_off*sr)];
% MFC 3
MFC_3 = [zeros(1,T_delay*sr) cleanairpoint*ones(1,(T_purge+T_flush+T-T_delay)*sr) zeros(1,T_off*sr)];
ControlParadigm(ci).Outputs = [0*MFC_1; MFC_2; MFC_3 ; Air; Pulse; Blank];
ControlParadigm(ci).Name = 'Control';

%% then make one for 1:Inf dilution (same as control switch, but through odour valve)
ci = length(ControlParadigm) + 1;
MFC_2 = MFC_2*CorrectionFactor(ci);

ControlParadigm(ci).Outputs = [0*MFC_1; MFC_2; MFC_3 ; Air; Blank; Pulse];
ControlParadigm(ci).Name = 'Dilution_1_Inf';


