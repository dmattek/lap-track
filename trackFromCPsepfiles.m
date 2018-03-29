% Process CellProfiler output with XY positions of objects 
% in a time-lapse experiment.
% Wrapper for u-track LAP tracking
% Example call:
% trackFromCPsepfiles('exp1/cp.out/output/out_0001', 'objNuclei_1line.csv',
% 'trackXY_', '/opt/local/u-track/software')
% 
% Input params:
% inPathCP - Absolute path to directory with CP merged output
% inFileCPcsv - Name of the CP output file (must be converted to a 1-line header, prior to analysis!)
% inDirTrack - Directory name with LAP output (relative to inPathCP)
% inPathUtrack - Absolute path to u-track software

function trackRes = trackFromCPsepfiles(inPathCP, inFileCPcsv, inDirTrack, inPathUtrack)

trackRes=0;
addpath(genpath(inPathUtrack))

%% Prepare data

% Absolute path to directory with CP merged output
fname.pathcp = inPathCP;

% Name of the CP output file
% In CP, when measuring multiple objects and merging output together,
% the output csv file has a 2-row header.
% In order to use this script, the header has to be converted to a single
% line.
fname.cpcsv = inFileCPcsv;

% CP output core name
fname.cpcsvcore = extractBefore(fname.cpcsv, '.');

% Directory name with LAP output (relative to fname.dir.cp)
fname.dirlap = strcat(inDirTrack, fname.cpcsvcore); 

% Absolute path to directory with LAP output
fname.pathlap = sprintf('%s/%s',fname.pathcp, fname.dirlap);

% create if doesn't exist
if ~exist(fname.pathlap, 'dir')
  mkdir(fname.pathlap);
end

% Read CP output
dat = readtable(sprintf('%s/%s', fname.pathcp, fname.cpcsv));

% Relevant column names in CP output
s.posx = 'objNuclei_Location_Center_X';
s.posy = 'objNuclei_Location_Center_Y';
s.cytoInt = 'objCytoRing_Intensity_MeanIntensity_imKTR';
s.nucInt = 'objNuclei_Intensity_MeanIntensity_imKTR';
s.meas = 'ratioCytoNuc'; % name of the new column with cyto/nuc ratio
s.time = 'Image_Metadata_T';
s.well = 'Image_Metadata_Well';
s.site = 'Image_Metadata_Site';


% Calculate cyto/nuc ratio of ERK-KTR
dat.ratioCytoNuc = dat.(s.cytoInt) ./ dat.(s.nucInt);


%% Analyse with u-track function scriptTrackGeneral

% define iterators
% get range of wells
all.wells = cell2mat(unique(dat.(s.well)));
szAllWells = size(all.wells);

% get range of FOV
all.fovs = unique(dat.(s.site));

%%
for iiWells = 1:szAllWells(1)
    for iiFovs = 1:length(all.fovs)

        % create file names for outputs
        % file with tracks
        curr.well = all.wells(iiWells, :);
        curr.fov = all.fovs(iiFovs);
        
        fname.tr = sprintf('%s/%s_Well%s_S%02d_tracks.csv', fname.pathlap, fname.cpcsvcore, curr.well, curr.fov);
        
        % file with connectivities (further analyzed with R script)
        fname.con = sprintf('%s/%s_Well%s_S%02d_conn.csv', fname.pathlap, fname.cpcsvcore, curr.well, curr.fov);
        
        % file with sequence of events in a track (further analyzed with R
        % script)
        fname.seq = sprintf('%s/%s_Well%s_S%02d_seq.csv', fname.pathlap, fname.cpcsvcore, curr.well, curr.fov);

        % write header to connectivity file
        fid = fopen(fname.con, 'w');
        fprintf(fid, 'Image_Metadata_Well_num,Image_Metadata_Site,track_id,Image_Metadata_T,ObjectNumber\n');
        fclose(fid);

        % write hearder to sequence file
        fid = fopen(fname.seq, 'w');
        fprintf(fid, 'Image_Metadata_Well_num,Image_Metadata_Site,track_id,track_start,track_end\n');
        fclose(fid);
        
        
        fprintf('\n=============================\nAnalyzing well %s (%d out of %d)\n', curr.well, iiWells, szAllWells(1))
        fprintf('Analyzing FOV %d (%d out of %d)\n', curr.fov, iiFovs, length(all.fovs))

        
        % get object coordinates from a single field of view;
        % all time points for that FOV
        datI = dat(categorical(dat.(s.well)) == curr.well & dat.(s.site) == curr.fov, :);

        % get range of frame numbers (here from time column of CP output)
        fov.tpts = unique(datI.(s.time));

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
            col1 = datI.(s.posx)(datI.(s.time) == fov.tpts(iiTpts));
 
            % vector with std of data 
            % it's all 0, hence same for all variables
            col2 = zeros(length(col1), 1);

            v1(:, iiTpts) = {[col1 col2]};
    
            col1 = datI.(s.posy)(datI.(s.time) == fov.tpts(iiTpts));
            v2(:, iiTpts) = {[col1 col2]};
    
            col1 = datI.(s.meas)(datI.(s.time) == fov.tpts(iiTpts));
            v3(:, iiTpts) = {[col1 col2]};

        end

        % build final input for scriptTrackGeneral
        movieInfo = struct(f1, v1, f2, v2, f3, v3);

        % Build tracks from x-y coordinates using u-track
        myScriptTrackGeneral

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
                        
            trackAll = [trackAll; table(repelem(cellstr(curr.well), trackLength, 1), repelem(curr.fov, trackLength, 1), repelem(ii, trackLength, 1), ((trackStart-1):(trackEnd-1))', matI(:, 1), matI(:, 2), matI(:, 4))];
        end
        
        % set column names
        trackAll.Properties.VariableNames = {s.well, s.site, 'track_id', s.time, s.posx, s.posy, s.meas};
        trackSeq.Properties.VariableNames = {s.well, s.site, 'track_id', 'track_start', 'track_end'};
        trackCon.Properties.VariableNames = {s.well, s.site, 'track_id', s.time, 'ObjectNumber'};

        % Write to a CSV
        writetable(trackAll, fname.tr)
        writetable(trackSeq, fname.seq)
        writetable(trackCon, fname.con)

    end
end

fprintf('\nFinished processing\n')

