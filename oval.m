% oval.m
% created by G S Srinivas ( http://srinivas.gs ) @ 14:29 on Wednesday the
% 23th of February, 2011
% oval is a better version of round, which rounds to how manyever
% significant digits you want
function [r] = oval(a,s)
% fix for negative numbers
if a <0
	flip=1;
else
	flip = 0;
end
a= abs(a);
powerbase = round(log10(a));
if powerbase > s  
else
    s = s - powerbase;
end
% get as many significant digits as needed before 0
    a = round(a*10^(s));
    % get back to the original number
    r = mat2str(a*10^(-s));

if flip
	r = strcat('-',r);
end