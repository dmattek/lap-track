% Assign parameter value from cell array
%
% Cell array (inParTab) contains two columns: parameter name and value.
% Names of these columns are given by inParTabColParName and
% inParTabColParVal.
% This function searches for parameter name given by inParName, and returns
% a value if this parameter is fiund in the cell array inParTab.
% If parameter is essential (inEssential=true) and is not found in
% inParTab, function returns an error message.
% If parameter is not essential (inEssential=false) and is not found in inParTab, function
% assigns a default value given by inDefaultVal.

function assignParRes = assignPar(inParName, inParTab, inParTabColParName, inParTabColParVal, inEssential, inDefaultVal)

if (ismember(inParName, inParTab.(inParTabColParName)))
    locPar = inParTab.(inParTabColParVal)( strcmp(inParTab.(inParTabColParName), inParName) );
    assignParRes = locPar{1};

else
    if (inEssential)
        fprintf('\nParameter %s not found in the config file. Please provide!\n', inParName)
        return
    else
        fprintf('\nParameter %s not found in the config file. Using default value!\n', inParName)
        assignParRes = inDefaultVal;
    end
end

