% Kontroller_ntrials
% calculates the number of trials in each paradigm in the data structure
% 
% created by Srinivas Gorur-Shandilya at 10:20 , 09 April 2014. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.

function n= Kontroller_ntrials(data)
n = zeros(1,length(data));
fl = fieldnames(data);
if isempty(fl)
	return;
end
for i = 1:length(data)
	eval(strcat('n(i)=width(data(i).',fl{1},');'));
end