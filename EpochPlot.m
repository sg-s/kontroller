% EpochPlot.m
% part of the kontroller package
% 
% created by Srinivas Gorur-Shandilya at 10:20 , 09 April 2014. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.EpochPlot
% plots traces where differnet traces are coloured by epoch
function [] = EpochPlot(plothere,plotthese,time,data,Epochs,plot_length)

% trim data
if length(data) > plot_length-1
    last_data_point = find(isnan(data(1,:)),1,'first')-1;
    if plot_length > last_data_point
        time = time(1:plot_length);
        data = data(:,1:plot_length);
        Epochs = Epochs(1:plot_length);
    else
        time = time(plot_length-last_data_point+1:last_data_point);
        data = data(:,plot_length-last_data_point+1:last_data_point);
        Epochs = Epochs(plot_length-last_data_point+1:last_data_point);
    end
end



% compute epoch starts and stops
Epochs = Epochs(:);
nEpochs = length(unique(Epochs));
EpochBreaks = [1; find(abs(diff(Epochs))); length(Epochs)];

% define colors
c = {'k','g','r','b','m','k','g','r','b','m'};


% plot it
for i = 1:length(plothere)
	cla(plothere(i))
	for j = 1:length(EpochBreaks)-1
		thisEpoch = Epochs(EpochBreaks(j)+1);
		plot(plothere(i),time(EpochBreaks(j):EpochBreaks(j+1)),data(plotthese(i),EpochBreaks(j):EpochBreaks(j+1)),c{thisEpoch})

	end
end
