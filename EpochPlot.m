% EpochPlot.m
% part of the kontroller package
% 
% created by Srinivas Gorur-Shandilya at 10:20 , 09 April 2014. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.EpochPlot
% plots traces where differnet traces are coloured by epoch
function [] = EpochPlot(plothere,plotthese,time,data,FilterState,PlotHandles,plot_length)
% 
% trim data
if length(data) > plot_length-1
    last_data_point = find(isnan(data(1,:)),1,'first')-1;
    if plot_length > last_data_point

    else

            time = time(last_data_point-plot_length+1:last_data_point);
            time = time-max(time);
            data = data(:,last_data_point-plot_length+1:last_data_point);

            
    end
end


% check if we need to rescale X axis -- this way we only rescale the X axis
% once. 
xl = get(plothere(1),'XLim');
if xl(2) ~= max(time)
    for i = 1:length(plothere)
       
        set(plothere(i),'XLim',[min(time) 0])
    end
end



% plot it
for i = 1:length(plothere)
    if FilterState(i)
        % filter the data
        try
            filtered_trace = bandPass(data(plotthese(i),:),100,10);
        catch
            filtered_trace = data(plotthese(i),:);
        end
        set(PlotHandles(i),'XData',time,'YData',filtered_trace,'Color',[1 0 0]);
    else
        set(PlotHandles(i),'XData',time,'YData',data(plotthese(i),:),'Color',[0 0 0]);
    end
end


