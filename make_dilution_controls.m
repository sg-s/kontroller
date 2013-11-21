% make_dilution_controls.m
% makes the control paradigms for gas phase dilutions for the tethered
% flight assay. 
% this assumes there are 3 MFCs, and this is used by Kontroller to run
% experiments. 
% there are three MFCs, connected as follows:
% AO1       small MFC       MFC 1     this feeds into odour bottle.
% AO2       small MFC       MFC 2     this dilutes odour with air
% AO3       large MFC       MFC 2     this provides clean air for the valve; never mixes with odour         
%%
function [ControlParadigm] = make_dilution_controls(TotalFlow,T_pulse,CorrectionFactor)

sr = 1000; % sampling rate
T_purge = 2; % this is the time when the MFC is open to 1/5 of its max reading
T_flush = 10; % this is the time when the MFC is open to setpoint, but air is off
T_delay = 5; % this is the delay for the big MFC so that it only opens when the small MFC is open
T_air = 6;
%T_pulse = 3; 
T_off = 3;
T = T_purge +  T_flush + 2*T_air + T_pulse+T_off;
MaxFlow_small = 1000;
MaxFlow_large = 5000;

% TotalFlow = 300; % mL/min, in one arm of the device (there are 4 arms total)

Air = [zeros(1,(T_flush+T_purge)*sr) ones(1,(2*T_air+T_pulse)*sr) zeros(1,T_off*sr)];
Blank = 0*Air;
Pulse = [zeros(1,(T_flush+T_purge)*sr) zeros(1,(T_air)*sr) ones(1,T_pulse*sr) zeros(1,(T_air)*sr) zeros(1,T_off*sr)];
%% make the vectors--dilutor<odour
dilution_ranges = [Inf 9 4 1]; % (all these numbers):1
dr = 1./(dilution_ranges+1); % dilution ratios
for i = 1:length(dr)
    setpoint = CorrectionFactor(i)*5*(1-dr(i))*TotalFlow/MaxFlow_small; 
    airpoint = CorrectionFactor(i)*5*(dr(i))*TotalFlow/MaxFlow_small;
    
    cleanairpoint = 3*5*TotalFlow/MaxFlow_large;
    
    % MFC 1
    flushpoint = max(1,setpoint); % to initially open the MFC
    MFC_1 = [flushpoint*ones(1,T_purge*sr) setpoint*ones(1,(T_flush+T_pulse+2*T_air)*sr) zeros(1,T_off*sr)];
    
    % MFC 2
    if i == 1
        MFC_2 = 0*[flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T_pulse+2*T_air)*sr) zeros(1,T_off*sr)];
    else
        MFC_2 = [flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T_pulse+2*T_air)*sr) zeros(1,T_off*sr)];
    end
    
    
    % MFC 3
    MFC_3 = [zeros(1,T_delay*sr) cleanairpoint*ones(1,(T_purge+T_flush+T_pulse+2*T_air-T_delay)*sr) zeros(1,T_off*sr)];
    
    
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
    MFC_1 = [flushpoint*ones(1,T_purge*sr) setpoint*ones(1,(T_flush+T_pulse+2*T_air)*sr) zeros(1,T_off*sr)];
    
    % MFC 2
    MFC_2 = [flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T_pulse+2*T_air)*sr) zeros(1,T_off*sr)];
    
    % MFC 3
    MFC_3 = [zeros(1,T_delay*sr) cleanairpoint*ones(1,(T_purge+T_flush+T_pulse+2*T_air-T_delay)*sr) zeros(1,T_off*sr)];
    
    
    ControlParadigm(ci).Outputs = [MFC_1; MFC_2; MFC_3 ; Air; Blank; Pulse];
    ControlParadigm(ci).Name = strcat('Dilution_1_',mat2str(dilution_ranges(i)));
end

%% then make one more for the control switch
ci = length(ControlParadigm) + 1;
% MFC 2
airpoint = 5*TotalFlow/MaxFlow_small;
cleanairpoint = 3*5*TotalFlow/MaxFlow_large;
MFC_2 = [flushpoint*ones(1,T_purge*sr) airpoint*ones(1,(T_flush+T_pulse+2*T_air)*sr) zeros(1,T_off*sr)];
% MFC 3
MFC_3 = [zeros(1,T_delay*sr) cleanairpoint*ones(1,(T_purge+T_flush+T_pulse+2*T_air-T_delay)*sr) zeros(1,T_off*sr)];
ControlParadigm(ci).Outputs = [0*MFC_1; MFC_2; MFC_3 ; Air; Pulse; Blank];
ControlParadigm(ci).Name = 'Control';

%% then make one for 1:Inf dilution (same as control switch, but through odour valve)
ci = length(ControlParadigm) + 1;
MFC_2 = MFC_2*CorrectionFactor(ci);

ControlParadigm(ci).Outputs = [0*MFC_1; MFC_2; MFC_3 ; Air; Blank; Pulse];
ControlParadigm(ci).Name = 'Dilution_1_Inf';

%% then make one for the flush/purge
ci = length(ControlParadigm) + 1;
T_purge = 10; T_purge_stop = 3;
MFC_1 = [5*ones(1,T_purge*sr) zeros(1,T_purge_stop*sr)]; %$ MFC_1 open
MFC_2 = [5*ones(1,T_purge*sr) zeros(1,T_purge_stop*sr)]; %$ MFC_2 wide open
MFC_3 = [ones(1,T_purge*sr)  zeros(1,T_purge_stop*sr)]; %$ MFC_3 open a little bit to match the other two
Purge_Air = [ones(1,T_purge*sr) zeros(1,T_purge_stop*sr)];
Purge_Pulse = [ones(1,2*sr) zeros(1,2*sr) ones(1,2*sr) zeros(1,2*sr) ones(1,2*sr) zeros(1,T_purge_stop*sr)];
Purge_Blank = [ones(1,2*sr) zeros(1,2*sr) ones(1,2*sr) zeros(1,2*sr) ones(1,2*sr) zeros(1,T_purge_stop*sr)];

ControlParadigm(ci).Outputs = [MFC_1; MFC_2; MFC_3 ; Purge_Air; Purge_Blank; Purge_Pulse];
ControlParadigm(ci).Name = 'Purge';
