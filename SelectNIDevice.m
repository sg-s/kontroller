function UseThisDevice = SelectNIDevice(d)

% make descriptive labels
S = {};
for i = 1:length(d)
    S{i} = strkat(d(i).ID,'   ',d(i).Model);
end

% create a UI
[UseThisDevice,OK] = listdlg('ListSize',[400 200],'ListString',S,'SelectionMode','single','Name','Choose DAQ','PromptString','Kontroller has >1 DAQ device. Choose one','OKString','Use This');

if ~OK
    error('You did not specify which DAQ to use. Kontroller cannot continue')
end

