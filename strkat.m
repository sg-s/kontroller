% strkat.m
% created by strkat@srinivas.gs on the 7th of June 2013
% strkat.m is in the public domain
% strkat is an alternate version of strcat
% in strkat, white spaces are preserved, and '\n','\t' are respected. 
% known bug: if any one input has a \n character in it, it will fail. 
function [o] = strkat(varargin)
inputs = {};
for i = 1:nargin
    inputs{i} = sprintf(varargin{i});
end
o = sprintf('%s','sprintf(',char(39),'%s',char(39));
for i = 1:nargin
    o=sprintf('%s',o,',sprintf(',char(39),varargin{i},char(39),')');
end
o=sprintf('%s','o=',o,');');
eval(o); 