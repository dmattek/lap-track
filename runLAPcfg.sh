# Script  name      : runLAP.sh
#
# Author            : Maciej Dobrzynski
#
# Date created      : 20180701
#
# Purpose           : Run LAP tracking analysis in the specified directory using lapconfig file.
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
#
# Run:
#  ./runLAP.sh -i ~/myexp1/cp.out/output/out_0001 -c lapconfig.csv
#
# The lapconfig.csv file is a two-column csv with a header: parameter, value.
# The file contains parameters for steps of the analysis listed above.
# 
# Tested on:
# Ubuntu 16.04.2 LTS
# MATLAB 2016b
# u-track 2.2.1
# R 3.2.3
# Python 3.5.2
#  
#####################################################################


# DEFINITIONS and default arguments
# Directory to work on
INDIRFLAG=false

# Config file
CFGFFLAG=false

# Path to directory with trackFromCPsepfilesCFG.m script to perform LAP tracking
DIRMSCR="/opt/local/misc-improc/lap-track"

# Path to directory with script_overlay.py script
# The script is part of https://github.com/majpark21/image_analysis.git
DIRPSCR="/opt/local/misc-improc/image_analysis"

# Path to directory with u-track
DIRUSCR="/opt/local/u-track/software"


# READ ARGUMENTS
TEMP=`getopt -o i:c: --long indir:cfgfile: -n 'runLAPcfg.sh' -- "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -i|--indir)
	    INDIRFLAG=true ;
            case "$2" in
                "") shift 2 ;;
                *) INDIR=$2 ; shift 2 ;;
            esac ;;
        -c|--cfgfile)
	    CFGFFLAG=true ;
            case "$2" in
                "") shift 2 ;;
                *) CFGF=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if ! $INDIRFLAG
then
    echo -e "\nWorking directory must be specified with -i\n"
    exit
fi

if ! $CFGFFLAG
then
    echo -e "\nConfig file (e.g. lapconfig.csv) must be specified with -c\n"
    exit
fi


# Convert relative path to absolute
INDIRFULL=`readlink -f $INDIR`
CFGFFULL=`readlink -f $CFGF`


# ANALYSIS

# Run R script to convert CP output from 2- to 1-line header, and remove unnecessary or duplicated columns
# Takes the input file and writes the result in $FCP1LHALL
echo -e "\n1. Convert and clean CP output"
echo "Config file: $CFGF"
echo "Input file:  $INDIRFULL"

runrscript.sh $DIRMSCR/cleanCPoutCFG.R $CFGFFULL $INDIRFULL



# Run MATLAB script with LAP tracking
# Changes to $INDIR directory, places output in $DIRLAPOUTALL sub-directory
# Matlab script works with the prefix for the output directory

echo -e "\n2. Run LAP tracking in Matlab"
CMDMAT='cd '"'"$DIRMSCR"'"'; path(pathdef); trackFromCPsepfilesCFG('"'"$CFGFFULL"'"', '"'"$INDIRFULL"'"'); quit'
echo $CMDMAT
matlab2016 -nodisplay -nosplash -nodesktop -r "$CMDMAT"


# Overlay track IDs onto segmented images
# The resulting images are placed in a directory ...
echo -e "\n3. Overlay track IDs onto segmented images"

python3 $DIRPSCR/script_overlay_cfg.py -c $CFGFFULL -d $INDIRFULL 


# Create final CSV with origianal CP output + track ID
# Arguments for this script are:
# - absolute path to directory to work on
# - filename with CP output (1-line header; no extension, just core filename)
# - sub-directory with LAP output
# - integer threshold for track lengths; only track longer than that will be saved
echo -e "\n4. Generate final CSV with tracks"
runrscript.sh $DIRMSCR/analConnCFG.R $CFGFFULL $INDIRFULL


# Remove intermediate file: CP output with 1-line header
FREM=$(grep file_cpout_1line $CFGFFULL | awk -F "," '{print $2}')
cd $INDIRFULL
rm $FREM
