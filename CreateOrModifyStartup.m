% CreateOrModifyStartup.m
% creates a startup file, if there is none. if there is one, modifies it to
% configure em. 
% check for startup.m
u = userpath;
u = u(1:end-1);
if  exist(strcat(u,'\startup.m'),'file') == 2
    % startup already exists
elseif  exist(strcat(u,'\startup.m'),'file') ==0 
    % doesn't exist. create it. 
end