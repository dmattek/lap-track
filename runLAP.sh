#!/bin/bash

#####################################################################
# Script  name      : runLAP.sh
#
# Author            : Maciej Dobrzynski
#
# Date created      : 20180328
#
# Purpose           : Run LAP tracking analysis in the specified directory.
#
# Detailed          : The script performs a series of steps
#                     1. Load raw CellProfiler CSV output, 
#                        remove duplicated columns and convert 2-line header to a single line;
#                        save result in another CSV file (e.g. xxx_1line.csv)
#                     2. Run LAP Matlab tracking (u-track software)
#                        the script loads xxx_1line.csv, 
#                        saves the output in a sub-folder of the path given as arg of this script (e.g. trackXY_xxx)
#                     3. Overlay trackIDs on segmented png's from CP
#                        New images are saved in a sub-directory (e.g. segmented_over
#                     4. Produce final CSV with original CP output + track IDs
#                        Only tracks longer than threshold NTRACKLENGTH are saved
#
# Requirements      : The following software and scripts are required:
#                     1. R scripts from 
#                        https://github.com/dmattek/Paolo-MCF10A-timelapse.git
#                        (a) to clean raw CP output, cleanCPout.R
#                        (b) to generate final output from LAP tracking, analConn.R
#
#                     2. u-track LAP tracking software:
#                        http://www.utsouthwestern.edu/labs/danuser/software/#utrack_anc
#
#                     3. Wrapper MATLAB scripts for u-track, 
#                        trackFromCPsepfiles.m and myScriptTrackGeneral.m
#
#                     4. MATLAB binary in search path (called with 'matlab')
#
#                     5. Python scrpt to overlay track IDs, script_overlay.py, from
#                        https://github.com/majpark21/image_analysis.git
#                     
#
# Example usage:
#  assume we have a directory ~/myexp1/cp.out/output/out_0001
#  with CellProfiler output from batch analysis. Run:
#  ./runLAP.sh -n 10 path_to_directory
#
# where "-n 10" is the threshold for minimum length of single-cell tracks that will be output in the final CSV
# 
# Tested on:
# Ubuntu 16.04.2 LTS
# MATLAB 2016b
# u-track 2.2.1
# R 3.2.3
# Python 3.5.2
#  
#####################################################################


# DEFINITIONS
# Directory to work on
INDIR=/mnt/imaging.data/Paolo/MCF10A_TimeLapse/2018-03-26_MCF10Amutants_H2B-miRFP_ERKKTR-Turq_FoxO-NeonGreen_40xAir_T5min_Stim15min-1ngmlEGF_24h-starving+CO2/cp.out2/output/out_0003

# Threshold for track length; only track longer than that will be saved
NTRACKLENGTH=10

# Core of the CSV file name with raw CP output (e.g. objNuclei; don't include the csv extension)
FCPRAW="objNuclei"

# Extension of csv files
FCPEXT=".csv"

# Suffix for the filename with 1-line header
FCPOUT1LH="_1line"

# Prefix for the folder with LAP tracking output
DIRLAPOUT="trackXY_"

# Path to directory with cleanCPout.R script.
# The script converts CP output from 2- to 1-line header, and remove unnecessary or duplicated columns
# The script is part of https://github.com/dmattek/Paolo-MCF10A-timelapse.git
DIRRSCR="/opt/local/misc-improc/Paolo-MCF10A-timelapse"

# Path to directory with trackFromCPsepfiles.m script to perform LAP tracking
DIRMSCR="/opt/local/misc-improc/lap-track"

# Path to directory with script_overlay.py script
# The script is part of https://github.com/majpark21/image_analysis.git
DIRPSCR="/opt/local/misc-improc/image_analysis"

# Path to directory with u-track
DIRUSCR="/opt/local/u-track/software"

# Sub-directory (relative to $INDIR) with segmented images
# Track ID will be overlayed on these images
DIRIMSEG="segmented"

# Sub-directory (relative to $INDIR) to place images with overlaid track ID
DIRIMOVER="segmented_over"


# ANALYSIS
# Entire filename with raw CP output
FCPRAWALL=$FCPRAW$FCPEXT

# Entire filename with 1-line header CP output
FCP1LHALL=$FCPRAW$FCPOUT1LH$FCPEXT

# Entire directory (relative to $INDIR) name to place LAP output
DIRLAPOUTALL=$DIRLAPOUT$FCPRAW$FCPOUT1LH

# Run R script to convert CP output from 2- to 1-line header, and remove unnecessary or duplicated columns
# Takes the input file and writes the result in $FCP1LHALL
echo "1. Convert and clean CP output"
runrscript.sh $DIRRSCR/cleanCPout.R $INDIR/$FCPRAWALL $INDIR/$FCP1LHALL

# Run MATLAB script with LAP tracking
# Changes to $INDIR directory, places output in $DIRLAPOUTALL sub-directory
# Matlab script works with the prefix for the output directory

echo "2. Run LAP tracking"
CMDMAT='cd '"'"$DIRMSCR"'"'; trackFromCPsepfiles('"'"$INDIR"'"', '"'"$FCP1LHALL"'"', '"'"$DIRLAPOUT"'"', '"'"$DIRUSCR"'"'); quit'
matlab -nodisplay -nosplash -nodesktop -r "$CMDMAT"

# Overlay track IDs onto segmented images
# The resulting images are placed in a directory ...
echo "3. Overlay track IDs"

mkdir -p $INDIR/$DIRIMOVER
python3 $DIRPSCR/script_overlay.py $INDIR $DIRLAPOUTALL $DIRIMSEG $DIRIMOVER

# Create final CSV with origianal CP output + track ID
# Arguments for this script are:
# - absolute path to directory to work on
# - filename with CP output (1-line header; no extension, just core filename)
# - sub-directory with LAP output
# - integer threshold for track lengths; only track longer than that will be saved
echo "4. Generate final CSV with tracks longer than $NTRACKLENGTH"
runrscript.sh $DIRRSCR/analConn.R $INDIR $FCPRAW$FCPOUT1LH $DIRLAPOUT$FCPRAW$FCPOUT1LH $NTRACKLENGTH
