%% general parameters

%optional input:
gapCloseParam.diagnostics = 0; %1 to plot a histogram of gap lengths in the end; 0 or empty otherwise.



%% cost matrix for frame-to-frame linking

parameters1.kalmanInitParam = []; %Kalman filter initialization parameters.
% parameters.kalmanInitParam.searchRadiusFirstIteration = 10; %Kalman filter initialization parameters.

parameters1.useLocalDensity = 1; %1 if you want to expand the search radius of isolated features in the linking (initial tracking) step.
parameters1.nnWindow = gapCloseParam.timeWindow; %number of frames before the current one where you want to look to see a feature's nearest neighbor in order to decide how isolated it is (in the initial linking step).

%optional input
parameters1.diagnostics = []; %if you want to plot the histogram of linking distances up to certain frames, indicate their numbers; 0 or empty otherwise. Does not work for the first or last frame of a movie.

%function name
costMatrices(1).funcName = 'costMatRandomDirectedSwitchingMotionLink';
costMatrices(1).parameters = parameters1;
clear parameters

%% cost matrix for gap closing

%parameters
parameters2.brownStdMult = 3*ones(gapCloseParam.timeWindow, 1); %multiplication factor to calculate Brownian search radius from standard deviation.

parameters2.brownScaling = [0.25 0.01]; %power for scaling the Brownian search radius with time, before and after timeReachConfB (next parameter).
% parameters.timeReachConfB = 3; %before timeReachConfB, the search radius grows with time with the power in brownScaling(1); after timeReachConfB it grows with the power in brownScaling(2).
parameters2.timeReachConfB = gapCloseParam.timeWindow; %before timeReachConfB, the search radius grows with time with the power in brownScaling(1); after timeReachConfB it grows with the power in brownScaling(2).

parameters2.ampRatioLimit = []; %for merging and splitting. Minimum and maximum ratios between the intensity of a feature after merging/before splitting and the sum of the intensities of the 2 features that merge/split.

parameters2.lenForClassify = 5; %minimum track segment length to classify it as linear or random.

parameters2.useLocalDensity = 0; %1 if you want to expand the search radius of isolated features in the gap closing and merging/splitting step.
parameters2.nnWindow = gapCloseParam.timeWindow; %number of frames before/after the current one where you want to look for a track's nearest neighbor at its end/start (in the gap closing step).

parameters2.linStdMult = 3*ones(gapCloseParam.timeWindow,1); %multiplication factor to calculate linear search radius from standard deviation.

parameters2.linScaling = [1 0.01]; %power for scaling the linear search radius with time (similar to brownScaling).
% parameters.timeReachConfL = 4; %similar to timeReachConfB, but for the linear part of the motion.
parameters2.timeReachConfL = gapCloseParam.timeWindow; %similar to timeReachConfB, but for the linear part of the motion.

%optional; to calculate MS search radius
%if not input, MS search radius will be the same as gap closing search radius
parameters2.resLimit = []; %resolution limit, which is generally equal to 3 * point spread function sigma.

%NEW PARAMETER
parameters2.gapExcludeMS = 1; %flag to allow gaps to exclude merges and splits

%NEW PARAMETER
parameters2.strategyBD = -1; %strategy to calculate birth and death cost


%function name
costMatrices(2).funcName = 'costMatRandomDirectedSwitchingMotionCloseGaps';
costMatrices(2).parameters = parameters2;
clear parameters

%% Kalman filter function names

kalmanFunctions.reserveMem  = 'kalmanResMemLM';
kalmanFunctions.initialize  = 'kalmanInitLinearMotion';
kalmanFunctions.calcGain    = 'kalmanGainLinearMotion';
kalmanFunctions.timeReverse = 'kalmanReverseLinearMotion';

%% additional input

%saveResults
%saveResults.dir = '/project/biophysics/jaqaman_lab/vegf_tsp1/slee/VEGFR2/2015/20150312_HMVECp6_AAL/AAL-NoVEGF/Stream_10min/TrackingPackage/tracks/'; %directory where to save input and output
%saveResults.filename = 'tracksTest.mat'; %name of file where input and output are saved
saveResults = 0; %don't save results

%verbose state
verbose = 1;

%problem dimension
if (isfield(movieInfo, 'xCoord') && isfield(movieInfo, 'yCoord'))
    if (isfield(movieInfo, 'zCoord'))
        probDim = 3;
    else
        probDim = 2;
    end
else
    disp('Provide at least X and Y coordinates.')
    return
end

%% tracking function call

[tracksFinal,kalmanInfoLink,errFlag] = trackCloseGapsKalmanSparse(movieInfo,...
    costMatrices,gapCloseParam,kalmanFunctions,probDim,saveResults,verbose);

% for i = 1 : 12
%     movieInfoTmp((i-1)*1200+1:i*1200) = movieInfo((i-1)*1200+1:i*1200);
%     saveResults.filename = ['tracks1All_' sprintf('%02i',i) '.mat'];
%     [tracksFinal,kalmanInfoLink,errFlag] = trackCloseGapsKalmanSparse(movieInfoTmp,...
%         costMatrices,gapCloseParam,kalmanFunctions,probDim,saveResults,verbose);
%     clear movieInfoTmp
% end

%% ~~~ the end ~~~