function [] = PurgeValves(OptimiseThese)
% PurgeValves.m
% this function purges valves till it is clean. 

nsteps = 15; % max number of times to purge before giving up

%% make data vectors
cm = jet(10); % colour map

% input validation
if iscell(OptimiseThese)
    % match names to paradigm IDs
    ControlParadigm = make_dilution_controls(300,3,ones(1,12));
    temp= (find(ismember({ControlParadigm.Name},OptimiseThese)));
    if length(temp) ~= length(OptimiseThese)
        error('Cant find the paradigms you want.')
        % this means that none of the paradigm names match some of the
        % names requested. 
    else
        OptimiseThese = temp;
        clear temp
    end
    
end
% find purge paradigm
temp= (find(ismember({ControlParadigm.Name},'Purge')));
if isempty(temp)
    error('Cant find a purge paradigm')
else
    pp = temp;
end

%% load the control paradigm
clear ControlParadigm
filename=ls(strcat(date,'*Kontroller_Paradigm*.mat'));
if ~isempty(filename)
    load(filename)
else
    error('Cant find a control paradigm that was constructed today.')
end
for i = (OptimiseThese)
    pulse(i).m = NaN(1,nsteps);
    pulse(i).s = NaN(1,nsteps);
    padding1(i).m = NaN(1,nsteps);
    padding1(i).s = NaN(1,nsteps);
    padding2(i).m = NaN(1,nsteps);
    padding2(i).s = NaN(1,nsteps);
end

%% optimise
for i = OptimiseThese

    % make figure
    figure, hold on, suptitle(strcat('Purging Paradigm :',mat2str(i)))
    a(1) = subplot(1,2,1); hold on
    xlabel('Step #')
    ylabel('PID')
    a(2) = subplot(1,2,2); hold on
    ylabel('PID')
    xlabel('Time')

    for k = 1:nsteps        

        % purge
        Kontroller(0,ControlParadigm,pp,1000);
        
        % run a trial with Kontroller for this paradigm and get decent data
        goon=0;
        while goon == 0
            data = Kontroller(0,ControlParadigm,i,1000);
            % check if the airspeeds before and after the pulse are the
            % same
            PIDBeforePulse = mean(data(i).PID(14000:17000));
            PIDAfterPulse = mean(data(i).PID(22000:24000));
            if abs(PIDBeforePulse - PIDAfterPulse) < 0.01
                goon=1;
            else
                disp('PID trace looks weird. Repeating...')
            end
        end
        
       

        % calculate metrics
        pulse(i).m(k) = mean(data(i).PID(18300:18400));
        pulse(i).s(k) = std(data(i).PID(18300:18400));
        
        padding1(i).m(k) = mean(data(i).PID(17300:17400));
        padding1(i).s(k) = std(data(i).PID(17300:17400));
        
        padding2(i).m(k) = mean(data(i).PID(19300:19400));
        padding2(i).s(k) = std(data(i).PID(19300:19400));

                
        % update plot1
        axes(a(1))
        cla

            errorbar(1:nsteps,pulse(i).m,pulse(i).s,'r','LineWidth',2)
            errorbar(1:nsteps,padding1(i).m,padding1(i).s,'b','LineWidth',2)
            errorbar(1:nsteps,padding2(i).m,padding2(i).s,'b','LineWidth',2)

        
        % update plot2
        axes(a(2))
        cla
        plot(data(i).PID(16000:22000),'k')
        
        % should we go on?
        if (abs(pulse(i).m(k) - (padding1(i).m(k)  + padding2(i).m(k))/2 ) < (pulse(i).s(k) + padding1(i).s(k))/10) && k > 5

                disp('Valves have been purged')
                break

        else
            
            disp('Valves Still not clean.')
        end

 
        
    end

    
    disp('Saving Data...')
    savename = strcat('C:\AutoTune Calibration Plots\PIDPurge_',date,'_Paradigm_',mat2str(i),'-',uid,'.fig');
    saveas(gcf,savename);
    close(gcf)
    
end

