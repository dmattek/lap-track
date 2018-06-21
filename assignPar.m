function assignParRes = assignPar(inParName, inParTab, inParTabColParName, inParTabColParVal)

if (ismember(inParName, inParTab.(inParTabColParName)))
    locPar = inParTab.(inParTabColParVal)( strcmp(inParTab.(inParTabColParName), inParName) );
    assignParRes = locPar{1};

else
    fprintf('\nParameter %s not found in the config file. Please provide!\n', inParName)
    return
end

