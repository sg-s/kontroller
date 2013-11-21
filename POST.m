% POST.m
% performs a power-on self test
clear all
disp('Performing a power-on self test for the tethered flight assay')
status = zeros(1,100); % logical vector, each index passing a certain check
TestErrors = NaN(1,100); % this holds the error on each test.
testdata(1).Output = [];
%% ask the user to turn on air--check 1
h=helpdlg('Turn on air.','POST for TFA');
wait =1;
while wait
    try get(h,'Visible');
        pause(0.1)
    catch
        wait = 0;
    end
end
status(1) = 1;
%% ask the user to turn on MFCs
h=helpdlg('Turn on MFCs.','POST for TFA');
wait =1;
while wait
    try get(h,'Visible');
        pause(0.1)
    catch
        wait = 0;
    end
end
status(2) = 1;
%% ask the user to turn on PID
h=helpdlg('Turn on PID.','POST for TFA');
wait =1;
while wait
    try get(h,'Visible');
        pause(0.1)
    catch
        wait = 0;
    end
end
status(3) = 1;
%% ask the user to turn on suction
h=helpdlg('Turn on suction.','POST for TFA');
wait =1;
while wait
    try get(h,'Visible');
        pause(0.1)
    catch
        wait = 0;
    end
end
status(4) = 1;
%% ask the user to load an empty bottle
h=helpdlg('Load an empty bottle.','POST for TFA');
wait =1;
while wait
    try get(h,'Visible');
        pause(0.1)
    catch
        wait = 0;
    end
end
status(5) = 1;
%% ask the user to position anemometer, and turn it on. 
h=helpdlg('Position anemometer and turn on.','POST for TFA');
wait =1;
while wait
    try get(h,'Visible');
        pause(0.1)
    catch
        wait = 0;
    end
end
status(6) = 1;
%% ----- the actual tests ---- 
disp('Running self-tests....')
%% TEST 7
% check MFC 1 works
% run MFC1 to a few levels, and look at what it reports as its own flow
% levels
disp('Checking if MFC 1 works...')
ControlParadigm=[];
for i = 1:5
    ControlParadigm(i).Outputs = zeros(6,10000);
    ControlParadigm(i).Outputs(1,:) = [zeros(1,1000) (i/2)*ones(1,7000) zeros(1,2000)];
end
data = Kontroller(0,ControlParadigm,[1 2 3 4 5],1000);
err = zeros(1,5);
for i =1:5
    testdata(7).Output(i) = mean(data(i).MFC1_Flow(7000:8000));
    err(i)=abs(mean(data(i).MFC1_Flow(7000:8000))-ControlParadigm(i).Outputs(1,5000))/(ControlParadigm(i).Outputs(1,5000));
end
if  max(err)<0.01
    % ok. test passed
    status(7) = 1;
    disp('Test 7 passed.')
else
    warning('Test 7 failed!. MFC 1 does not work as expected')
    disp('These are the error sizes:')
    err
end
TestErrors(7) = max(err);



%% TEST 8
% check MFC 2 works
% run MFC1 to a few levels, and look at what it reports as its own flow
% levels
disp('Checking if MFC 2 works...')
ControlParadigm=[];
for i = 1:5
    ControlParadigm(i).Outputs = zeros(6,10000);
    ControlParadigm(i).Outputs(2,:) = [zeros(1,1000) (i/2)*ones(1,7000) zeros(1,2000)];
end
data = Kontroller(0,ControlParadigm,[1 2 3 4 5],1000);
err = zeros(1,5);
for i =1:5
    testdata(7).Output(i) = mean(data(i).MFC2_Flow(7000:8000));
    err(i)=abs(mean(data(i).MFC2_Flow(7000:8000))-ControlParadigm(i).Outputs(2,5000))/(ControlParadigm(i).Outputs(2,5000));
end
if  max(err)<0.01
    % ok. test passed
    status(8) = 1;
    disp('Test 8 passed.')
else
    warning('Test 8 failed! MFC_2 does not work as expected')
    disp('These are the error sizes:')
    err
end
TestErrors(8) = max(err);
%% TEST 9
% check air valves work,  and anemometer work
% send a pulse of air, and check that  airspeeds dip
disp('Checking air valves and anemometer...')
ControlParadigm=[];
ControlParadigm(1).Outputs = zeros(6,10000);
ControlParadigm(1).Outputs(1,:) = [(1.5)*ones(1,8000) zeros(1,2000)];
ControlParadigm(1).Outputs(2,:) = [(1.5)*ones(1,8000) zeros(1,2000)];
ControlParadigm(1).Outputs(3,:) = [(1.2)*ones(1,8000) zeros(1,2000)];
ControlParadigm(1).Outputs(4,:) = [zeros(1,4000) ones(1,2000) zeros(1,4000)];
data = Kontroller(0,ControlParadigm,ones(1,5),1000);

% save the test data
testdata(9).Output = data(1).Airspeeds;
if  mean(mean(data(1).Airspeeds(:,5000:6000))) < mean(mean(data(1).Airspeeds(:,1:4000)))
    status(9) = 1;
    disp('Test 9 passed.')
else
    warning('Test 9 failed! Either anemometer of valves dont work as expected.')

end

%% TEST 10
% run minimise airspeed differences on the paradigms you want
OptimiseThese = [1 4 12];  
PulseDuration = 0.2;
MinimiseAirspeedDifferences(OptimiseThese,PulseDuration)
%% ask the user to position the PID for flush check 
h=helpdlg('Remove anemometer, position PID.','POST for TFA');
wait =1;
while wait
    try get(h,'Visible');
        pause(0.1)
    catch
        wait = 0;
    end
end

%% Test 11
% make sure valves are completely flushed
OptimiseThese = {'Dilution_Inf_1','Dilution_1_1','Dilution_1_Inf'};  
PurgeValves(OptimiseThese);