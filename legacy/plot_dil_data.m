load c:\data\2013_08_01_gas_phase_dilution_1_MFC_check.mat
dr = zeros(1,length(data));
mr_12s = dr;
mr_5s = dr;
mr_18s = dr;

sr_6s = dr;
sr_9s = dr;
sr_12s = dr;

for i = 4:length(data)
    % calculate setpoint rtio
    dr(i) = (ControlParadigm(i).Outputs(1,12000)/ControlParadigm(i).Outputs(2,12000))/5;
    
    mr_6s(i) = mean(((mean(data(i).FlowSmall(:,12000:12100)))./(mean(data(i).FlowMain(:,12000:12100))))/5);
    sr_6s(i) = std(((mean(data(i).FlowSmall(:,12000:12100)))./(mean(data(i).FlowMain(:,12000:12100))))/5);
    
    mr_9s(i) = mean(((mean(data(i).FlowSmall(:,15000:15100)))./(mean(data(i).FlowMain(:,15000:15100))))/5);
    sr_9s(i) = std(((mean(data(i).FlowSmall(:,15000:15100)))./(mean(data(i).FlowMain(:,15000:15100))))/5);
    
    mr_12s(i) = mean(((mean(data(i).FlowSmall(:,18000:18100)))./(mean(data(i).FlowMain(:,18000:18100))))/5);
    sr_12s(i) = std(((mean(data(i).FlowSmall(:,18000:18000)))./(mean(data(i).FlowMain(:,18000:18100))))/5);
    
end

%% plot
figure, hold on
errorbar(dr,mr_6s-dr,sr_6s,'b','LineWidth',2)
hold on
errorbar(dr,mr_9s-dr,sr_9s,'r','LineWidth',2)
errorbar(dr,mr_12s-dr,sr_12s,'g','LineWidth',2)