% install_Kontroller.m
% 
% 
% created by Srinivas Gorur-Shandilya at 10:20 , 09 April 2014. Contact me at http://srinivas.gs/contact/
% 
% This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. 
% To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
% this little matlab script downloads and installs everything needed for Kontroller.m to work. 
clc

disp('I will try to intall Kontroller on this computer...')
links = {'https://github.com/sg-s/kontroller/zipball/master'};

n = numel(links);
for i = 1:n

    % local file
    linki = links{i};
    [pathstr, name, ext ] = fileparts(linki);
    fname = [tempdir name ext];

    disp(['Downloading: ' fname]);

    % open local file
    fh = fopen(fname, 'wb');

    if fh == -1
        msg = 'Unable to open file %s';
        msg = sprintf(msg, fname);
        error(msg);
    end

    % open remote file via Java net.URL class
    jurl = java.net.URL(linki);
    is = jurl.openStream;
    b = 0;
    while true
        b = is.read;
        if b == -1
            % eof
            break
        end
        fwrite(fh, b, 'uint8'); %!!! doesn't work with 'char';
    end
    is.close; % close java stream

    fh = fclose(fh);
    if fh == -1
        msg = 'Unable to close file %s';
        msg = sprintf(msg, fname);
        error(msg);
    end

end

% get windows home directory
try
    userDir = winqueryreg('HKEY_CURRENT_USER',['Software\Microsoft\Windows\CurrentVersion\','Explorer\Shell Folders'],'Personal');
catch
    error('Kontroller can only work on a Windows machine');
end

outputdir = 

disp('Done')