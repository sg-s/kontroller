function [] = MinimiseAirspeedDifferences(OptimiseThese,PulseDuration)
% MinimiseAirspeedDifferences.m
% this script makes a control paradigm to optimise the flow rates so that
% the airspeeds are minimised. 

%% ~~~~~~~~~~ CHOOSE PARADIGMS TO OPTIMISE ~~~~~~

nsteps = 10; % only ten steps max.

%% make data vectors
cm = jet(10); % colour map
OptimisationData(1).CF = zeros(1,nsteps); % correction factor
OptimisationData(1).DA = zeros(1,nsteps); % delta airspeed
CorrectionFactor = ones(1,13); % this is to correct for non-equal flows b/w odour and control arms
% intialise. 
%% CORRECTION FACTORS FOR GLASS Y--inital conditions
CorrectionFactor(7) = 0.87;  % 1:5 dilution
CorrectionFactor(6) = 0.87;  % 1:3 dilution
CorrectionFactor(5) = 0.84;  % 1:2 dilution
CorrectionFactor(4) = 0.91;  % 1:1 dilution
CorrectionFactor(1) = 0.81;  % Inf:1 dilution

if iscell(OptimiseThese)
    % match names to paradigm IDs
    ControlParadigm = make_dilution_controls(300,3,CorrectionFactor);
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

%% optimise
for i = OptimiseThese
    maxCF = 1.3;
    minCF = 0.7;
    thisCF = CorrectionFactor(i);
    % make figure
    figure, hold on, suptitle(strcat('Optimising Paradigm :',mat2str(i)))
    a(1) = subplot(2,2,1); hold on
    xlabel('Step #')
    ylabel('CorrectionFactor')
    a(2) = subplot(2,2,2); hold on
    ylabel('\Delta Airspeed')
    xlabel('Step #')
    a(3) = subplot(2,2,3); hold on
    ylabel('\Delta Airspeed')
    xlabel('CorrectionFactor')
    a(4) = subplot(2,2,4); hold off
    ylabel(' Airspeed')

    for k = 1:nsteps
        % update values
        OptimisationData(i).CF(k) = thisCF;
        CorrectionFactor(i) = thisCF;
        
        % make control paradigms 
        ControlParadigm = make_dilution_controls(300,3,CorrectionFactor);
        
        % run a trial with Kontroller for this paradigm and get decent data
        goon=0;
        while goon == 0
            data = Kontroller(0,ControlParadigm,i,1000);
            % check if the airspeeds before and after the pulse are the
            % same
            SpeedBeforePulse = mean(data(i).Airspeeds(14000:17000));
            SpeedAfterPulse = mean(data(i).Airspeeds(22000:24000));
            if abs(SpeedBeforePulse - SpeedAfterPulse) < 0.01
                goon=1;
            else
                disp('Airspeed trace looks weird. Repeating...')
            end
        end
        
        
        % plot the airspeed trace
        plot(data(i).Airspeeds(16000:27000),'Color','k')

        % calculate the delta airspeed
        padding = - mean([data(i).Airspeeds(22000:24000) data(i).Airspeeds(14000:16000)]);
        pulse = -  mean(data(i).Airspeeds(18000:21000));
        OptimisationData(i).DA(k) = pulse-padding;
        
        % figure out wheter to increse or decrease CF
        if OptimisationData(i).DA(k) < 0
            % set min to current value
            minCF = thisCF;
            % increase CF
            thisCF = (thisCF+maxCF)/2;
        else
            % set max to current value
            maxCF = thisCF;
            % decrease CF
            thisCF = (thisCF+minCF)/2;
        end
        
        % update correction factor plot
        scatter(a(1),k,OptimisationData(i).CF(k),'filled')
        
        % update Delta airspeed plot
        scatter(a(2),k,OptimisationData(i).DA(k),'filled')
        
        % update 3rd plot
        scatter(a(3),OptimisationData(i).CF(k),OptimisationData(i).DA(k))
 
        
    end
    % fit a line
    [f,gof]=fit(OptimisationData(i).CF',OptimisationData(i).DA','poly1');
    x=min(OptimisationData(i).CF):0.01:max(OptimisationData(i).CF);
    
    % plot it
    plot(a(3),x,f(x),'r','LineWidth',2)
    title(a(3),strcat('R-square:', oval(gof.rsquare,3)))
    
    title(a(4),strcat('Airspeed change :',oval(OptimisationData(i).DA(nsteps),3)))
    
    disp('Saving Data...')
    savename = strcat('C:\AutoTune Calibration Plots\AutoTune_',date,'_Paradigm_',mat2str(i),'-',uid,'.fig');
    saveas(gcf,savename);
    close(gcf)
    
end

%% at the end, make control paradigm with chosen T-pulse and save it
ControlParadigm = make_dilution_controls(300,PulseDuration,CorrectionFactor);
savename = strcat(date,'_Kontroller_Paradigm_AutoTuned_300_200ms.mat');
save(savename,'ControlParadigm');
% also make a 3-second long version
ControlParadigm = make_dilution_controls(300,3,CorrectionFactor);
savename = strcat(date,'_Kontroller_Paradigm_AutoTuned_300_3s.mat');
save(savename,'ControlParadigm');
