% Process CellProfiler output with XY positions of objects 
% in a time-lapse experiment.
% Wrapper for u-track LAP tracking
% 
% Input params:
% inFileConfig - A csv file with parameter names; should contain two
%                columns with a header (parameter, value)
% inPathCP - Absolute path to directory with CP merged output
%
% Example call:
% trackFromCPsepfiles('exp1/cp.out/lapconfig.csv', 'exp1/cp.out/output/out_0001')
%
% Note: uses assignPar function for a
% Parameters used from the config file:
% file_cpout_1line
% dir_lapout
% file_cpout_1line
% dir_lapout
% column_well
% column_fov
% column_frame
% column_posx
% column_posy
% 


function trackRes = trackFromCPsepfilesCFG(inFileConfig, inPathCP)

trackRes=0;

%% Parse config file

% Set params
% column name in config file with parameter names
cfgpar.colpar = 'parameter';

% column name in config file with parameter values
cfgpar.colval = 'value';

% names of parameters from the config file required in this script

% single-line header file with CP output;
% usually crerated by cleanCPoutCFG.R script
% e.g. objNuclei_1line.csv
cfgpar.cpout1line = 'file_cpout_1line';


cfgpar.dirtracks = 'dir_lapout';
cfgpar.col_well = 'column_well';
cfgpar.col_fov = 'column_fov';
cfgpar.col_frame = 'column_frame';
cfgpar.col_posx = 'column_posx';
cfgpar.col_posy = 'column_posy';

% Read config file
cfgtab = readtable(inFileConfig, 'ReadVariableNames', true, 'ReadRowNames', false, 'delimiter', ',');

% Assign parameters from the config file (essential)
par.cpout1line = assignPar(cfgpar.cpout1line, cfgtab, cfgpar.colpar, cfgpar.colval, true);
par.dirtracks  = assignPar(cfgpar.dirtracks,  cfgtab, cfgpar.colpar, cfgpar.colval, true);
par.col_well   = assignPar(cfgpar.col_well,   cfgtab, cfgpar.colpar, cfgpar.colval, true);
par.col_fov    = assignPar(cfgpar.col_fov,    cfgtab, cfgpar.colpar, cfgpar.colval, true);
par.col_frame  = assignPar(cfgpar.col_frame,  cfgtab, cfgpar.colpar, cfgpar.colval, true);
par.col_posx   = assignPar(cfgpar.col_posx,   cfgtab, cfgpar.colpar, cfgpar.colval, true);
par.col_posy   = assignPar(cfgpar.col_posy,   cfgtab, cfgpar.colpar, cfgpar.colval, true);

%% Assign parameters from the config file (non-essential, with default)
% gapCloseParam, parameters1, parameters2 are used in
% myScriptTrackGeneralCFG to run tracking
% ONLY essential parameters are assigned here, the remaining are in
% myScriptTrackGeneralCFG

% general gap closing parameters
% maximum allowed time gap (in frames) between a track segment end and a track segment start that allows linking them.
gapCloseParam.timeWindow = assignPar('lap_timewindow', cfgtab, cfgpar.colpar, cfgpar.colval, false, 2);

% Set 1 if merging and splitting are to be considered, 2 if only merging is to be considered, 3 if only splitting is to be considered, 0 if no merging or splitting are to be considered.
gapCloseParam.mergeSplit = assignPar('lap_mergesplit', cfgtab, cfgpar.colpar, cfgpar.colval, false, 0);

% minimum length of track segments from linking to be used in gap closing.
gapCloseParam.minTrackLen = assignPar('lap_mintracklen', cfgtab, cfgpar.colpar, cfgpar.colval, false, 1);


% parameters for cost matrix for frame-to-frame linking
% use linear motion Kalman filter
parameters1.linearMotion = assignPar('lap_fflink_linmotion', cfgtab, cfgpar.colpar, cfgpar.colval, false, 0);

% minimum allowed search radius. The search radius is calculated on the spot in the code given a feature's motion parameters. If it happens to be smaller than this minimum, it will be increased to the minimum.
parameters1.minSearchRadius = assignPar('lap_fflink_minrad', cfgtab, cfgpar.colpar, cfgpar.colval, false, 10);

% maximum allowed search radius. Again, if a feature's calculated search radius is larger than this maximum, it will be reduced to this maximum.
parameters1.maxSearchRadius = assignPar('lap_fflink_maxrad', cfgtab, cfgpar.colpar, cfgpar.colval, false, 20);

% multiplication factor to calculate search radius from standard deviation
parameters1.brownStdMult = assignPar('lap_fflink_brownstdmult', cfgtab, cfgpar.colpar, cfgpar.colval, false, 3);



% cost matrix for gap closing
% needed all the time

% use linear motion Kalman filter
parameters2.linearMotion = assignPar('lap_gapclose_linmotion', cfgtab, cfgpar.colpar, cfgpar.colval, false, 0);

% minimum allowed search radius. The search radius is calculated on the spot in the code given a feature's motion parameters. If it happens to be smaller than this minimum, it will be increased to the minimum.
parameters2.minSearchRadius = assignPar('lap_gapclose_minrad', cfgtab, cfgpar.colpar, cfgpar.colval, false, 10);

% maximum allowed search radius. Again, if a feature's calculated search radius is larger than this maximum, it will be reduced to this maximum.
parameters2.maxSearchRadius = assignPar('lap_gapclose_maxrad', cfgtab, cfgpar.colpar, cfgpar.colval, false, 10);

% maximum angle between the directions of motion of two tracks that allows linking them (and thus closing a gap). Think of it as the equivalent of a searchRadius but for angles.
parameters2.maxAngleVV = assignPar('lap_gapclose_maxangle', cfgtab, cfgpar.colpar, cfgpar.colval, false, 30);

% optional; if not input, 1 will be used (i.e. no penalty)
% penalty for increasing temporary disappearance time (disappearing for n frames gets a penalty of gapPenalty^(n-1)).
parameters2.gapPenalty = assignPar('lap_gapclose_gappen', cfgtab, cfgpar.colpar, cfgpar.colval, false, 1.5);




%% Prepare data for tracking

% Absolute path to directory with CP output, e.g.
% /home/user/myexp1/output/out_0001
% Usually this directory holds output with a single FOV
fname.pathcp = inPathCP;

% CP output core name
fname.cpcsvcore = extractBefore(par.cpout1line, '.');

% Absolute path to directory with LAP output
fname.pathlap = sprintf('%s/%s', fname.pathcp, par.dirtracks);

% create if doesn't exist
if ~exist(fname.pathlap, 'dir')
  mkdir(fname.pathlap);
end

% Read CP output
% Use TreatAsEmpty option to handle NAs in CP output
% Without this option, a numeric column with NAs is read as string
dat = readtable(sprintf('%s/%s', fname.pathcp, par.cpout1line), 'TreatAsEmpty',{'NA'});


% Check whether column names exist in data
s.vars = dat.Properties.VariableNames;

if (sum(contains(s.vars, par.col_posx)) == 0)
  disp('No column with X position')
  return 
end

if (sum(contains(s.vars, par.col_posy)) == 0)
  disp('No column with Y position')
  return 
end

if (sum(contains(s.vars, par.col_frame)) == 0)
  disp('No column with metadata time')
  return 
end

bWellExists = 1;

if (sum(contains(s.vars, par.col_well)) == 0 || strcmp(par.col_well, 'none'))
  disp('No column with metadata well; assuming one well')
  bWellExists = 0;
  szAllWells = 1;
  all.wells = '0';
  par.col_well = 'Image_Metadata_Well'
else
    sTmp = unique(dat.(par.col_well));
    bWellExists = 1;
    disp('Column with metadata well exists')
    all.wells = cell2mat(sTmp);
    szAllWells = size(all.wells);
    szAllWells = szAllWells(1);
end

if (sum(contains(s.vars, par.col_fov)) == 0)
  disp('No column with metadata site')
  return 
end


%% Analyse with u-track function scriptTrackGeneral

% define iterators
% get range of wells

if (bWellExists)
  sTmp = unique(dat.(par.col_well));
  % even if the column with metadata well exists, it might contain NaN's; checking here
  if (sum(isnan(sTmp{1})) > 0)
    disp('Column with metadata well contains NaN; assuming one well')
    szAllWells = 1;
    all.wells = '0';
    bWellExists = 0;
  end
end

% get range of FOV
all.fovs = unique(dat.(par.col_fov));

%%
for iiWells = 1:szAllWells
    for iiFovs = 1:length(all.fovs)

        % create filenames for outputs
        % file with tracks
        curr.well = all.wells(iiWells, :);
        curr.fov = all.fovs(iiFovs);
        
        fname.tr = sprintf('%s/%s_Well%s_S%02d_tracks.csv', fname.pathlap, fname.cpcsvcore, curr.well, curr.fov);
        
        % file with connectivities (further analyzed with R script)
        fname.con = sprintf('%s/%s_Well%s_S%02d_conn.csv', fname.pathlap, fname.cpcsvcore, curr.well, curr.fov);
        
        % file with sequence of events in a track (further analyzed with R
        % script)
        fname.seq = sprintf('%s/%s_Well%s_S%02d_seq.csv', fname.pathlap, fname.cpcsvcore, curr.well, curr.fov);

        % console info output 
        fprintf('\n=============================\nAnalyzing well %s (%d out of %d)\n', curr.well, iiWells, szAllWells)
        fprintf('Analyzing FOV %d (%d out of %d)\n', curr.fov, iiFovs, length(all.fovs))

        
        % get object coordinates from a single field of view;
        % all time points for that FOV
        if (bWellExists)
          datI = dat(categorical(dat.(par.col_well)) == curr.well & dat.(par.col_fov) == curr.fov, :);
        else
          datI = dat(dat.(par.col_fov) == curr.fov, :);
        end

        % get range of frame numbers (here from time column of CP output)
        fov.tpts = unique(datI.(par.col_frame));

        fprintf('%d frames\n\n', length(fov.tpts))

        % prepare cell array for analysis with u-track
        f1 = 'xCoord';
        f2 = 'yCoord';
        f3 = 'amp';

        v1 = {};
        v2 = {};
        v3 = {};

        for iiTpts = 1:length(fov.tpts)

            % vector with data
            col1 = datI.(par.col_posx)(datI.(par.col_frame) == fov.tpts(iiTpts));
 
            % vector with std of data 
            % it's all 0, hence same for all variables
            col2 = zeros(length(col1), 1);

            v1(:, iiTpts) = {[col1 col2]};
    
            col1 = datI.(par.col_posy)(datI.(par.col_frame) == fov.tpts(iiTpts));
            v2(:, iiTpts) = {[col1 col2]};
    
            % Measurement filled as zeroes
            %col1 = datI.(s.meas)(datI.(par.col_frame) == fov.tpts(iiTpts));
            v3(:, iiTpts) = {[col2 col2]};

        end

        % build final input for scriptTrackGeneral
        movieInfo = struct(f1, v1, f2, v2, f3, v3);

        % Build tracks from x-y coordinates using u-track
        % The script defines several parameters for linking frames and
        % closing gaps
        myScriptTrackGeneralCFG

        fprintf('Finished building tracks. Saving results for well:%s s:%d\n', curr.well, curr.fov)
        
        % final table with all tracks in a long format
        trackAll = table();

        % connectivity and sequence tables
        trackCon = table();
        trackSeq = table();
        
        % loop over all tracks
        for ii = 1:length(tracksFinal)
            % write sequence file (holds start and end frame of the track)
            seqI = tracksFinal(ii).seqOfEvents;
            trackStart = tracksFinal(ii).seqOfEvents(1,1);
            trackEnd   = tracksFinal(ii).seqOfEvents(2,1);            
            %dlmwrite(path.seq, [iiWells; all.fovs(iiFovs); ii; trackStart-1; trackEnd-1]', '-append');
            
            trackSeq = [trackSeq; table(cellstr(curr.well), curr.fov, ii, trackStart-1, trackEnd-1)];
            
            % write connectivity file
            connI = tracksFinal(ii).tracksFeatIndxCG;
            connIlength = length(connI);
            
            if ((trackEnd - trackStart + 1) == connIlength)
                %dlmwrite(path.con, [repelem(iiWells, connIlength); repelem(all.fovs(iiFovs), connIlength); repelem(ii, connIlength); (trackStart-1):(trackEnd-1); connI]', '-append');
                trackCon = [trackCon; table(repelem(cellstr(curr.well), connIlength, 1), repelem(curr.fov, connIlength, 1), repelem(ii, connIlength, 1), ((trackStart-1):(trackEnd-1))', connI')];
            else
                %dlmwrite(path.con, [repelem(iiWells, connIlength); repelem(all.fovs(iiFovs), connIlength); repelem(ii, connIlength); repelem(-1, connIlength); connI]', '-append');
                trackCon = [trackCon; table(repelem(cellstr(curr.well), connIlength, 1), repelem(curr.fov, connIlength, 1), repelem(ii, connIlength, 1), repelem(-1, connIlength, 1), connI')];
            end
            
            % export to a table in long format (compatible with timecourseAnalyzer app
            trackI = tracksFinal(ii).tracksCoordAmpCG;
            trackLength = length(trackI) / 8;
            matI = reshape(tracksFinal(ii).tracksCoordAmpCG, [8 trackLength])';
                        
            trackAll = [trackAll; table(repelem(cellstr(curr.well), trackLength, 1), repelem(curr.fov, trackLength, 1), repelem(ii, trackLength, 1), ((trackStart-1):(trackEnd-1))', matI(:, 1), matI(:, 2))];
        end
        
        % set column names
        trackAll.Properties.VariableNames = {par.col_well, par.col_fov, 'track_id', par.col_frame, par.col_posx, par.col_posy};
        trackSeq.Properties.VariableNames = {par.col_well, par.col_fov, 'track_id', 'track_start', 'track_end'};
        trackCon.Properties.VariableNames = {par.col_well, par.col_fov, 'track_id', par.col_frame, 'ObjectNumber'};

        % Write to a CSV
        writetable(trackAll, fname.tr)
        writetable(trackSeq, fname.seq)
        writetable(trackCon, fname.con)

    end
end

fprintf('\nFinished processing\n')

