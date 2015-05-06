%% filter trace (this is from spikesort)
function [V, Vf] = filter_trace(V)
    if any(isnan(V))
        % filter ignoring NaNs
        Vf = V;
        Vf(~isnan(V)) = filtfilt(ones(1,100)/100,1,V(~isnan(V)));
    else
        Vf = filtfilt(ones(1,100)/100,1,V);
    end
    
    V = V - Vf;
end
