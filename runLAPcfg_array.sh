#!/bin/bash

# Usage:
# runLAP_array -i foo/ [-nJct]

usage="This script run LAP tracking algorithm on CellProfiler CSV output. In addition it returns images overlaid with track ID.
It can be run on a directory which contains subdirectories, each of which contains an independent dataset for tracking.
See runLAP.sh for details of tracking steps.
It proceeds by first creating a file for submission of a SLURM array. In this array each subdirectoy is a different tak.
Usage:
$(basename "$0") [-h]
where:
	-h | --help		Show this Help text.
	-i | --indir		Path to data directory. This argument is mandatory.
	-J | --Jobname		Name of the SLURM job (default laptrack).
	-c | --core		Number of cores used by the array (default 1).
	-t | --time		Walltime for the task execution in format day-h:min (default 5 hours)."


# -------------- Bash part for taking inputs -----------

# Directory to work on
INDIRFLAG=false

# Config file
CFGFFLAG=false

SLOUTDIR=slurm.jobs

# Default parameters for slurm array and LAP
JOBNAME="laptrack"
TIME="01:00:00" # 1 hour

# Read arguments
TEMP=`getopt -o hi:c:J:T: --long help,indir:,cfgfile:Jobname:,Time: -n 'runLAPcfg_array.sh' -- "$@"`
eval set -- "$TEMP"

while true ; do
	case "$1" in
	-h|--help) echo -e "$usage"; exit;;
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
	-J|--jobname)
            case "$2" in
                "") shift 2 ;;
                *) JOBNAME=$2 ; shift 2 ;;
            esac ;;
	-T|--time)
            case "$2" in
                "") shift 2 ;;
                *) TIME=$2 ; shift 2 ;;
            esac ;;
	--) shift ; break ;;
     *) echo "Internal error!" ; exit 1 ;;
    esac
done

if ! $INDIRFLAG
then
    echo "Working directory must be specified with -i"
    exit
fi

if ! $CFGFFLAG
then
    echo -e "\nConfig file (e.g. lapconfig.csv) must be specified with -c\n"
    exit
fi


# -------------- Write the array submission file ------------------
# Create one task for each subfolder

# convert the input (relative) path to an absolute path
INDIR=`readlink -f $INDIR`

# Number of subfolder in the working directory (=number tasks)
NFOLD=`ls -1 $INDIR | grep -v '^slurm\|@eaDir' | wc -l`
echo "Number of tasks: $NFOLD"

# Directory for files array-related
mkdir -p $INDIR/$SLOUTDIR
mkdir -p $INDIR/$SLOUTDIR/out
mkdir -p $INDIR/$SLOUTDIR/err

# Create a file with job array for submission
FARRAY=$INDIR/$SLOUTDIR/$JOBNAME.sbatch

echo "#!/bin/bash" > $FARRAY
echo "#SBATCH --array=1-$NFOLD" >> $FARRAY 
echo "#SBATCH -J $JOBNAME # Single job name for the array" >> $FARRAY
echo "#SBATCH --mem-per-cpu=4096" >> $FARRAY
echo "#SBATCH -t $TIME # walltime" >> $FARRAY
echo "#SBATCH -o $INDIR/$SLOUTDIR/out/${JOBNAME}_array%A%a.out" >> $FARRAY
echo "#SBATCH -e $INDIR/$SLOUTDIR/err/${JOBNAME}_array%A%a.err" >> $FARRAY

# Select only the n-th subfolder, where n is the task ID
echo "SUBFOLD=\`ls '$INDIR' | grep -v '^slurm\|@eaDir' | head -\$SLURM_ARRAY_TASK_ID | tail -1\`" >> $FARRAY
echo "runLAPcfg.sh -c $CFGF -i $INDIR/\$SUBFOLD" >> $FARRAY
#echo "runLAPcfg.sh $@" >> $FARRAY

# Submit jobs
sbatch $FARRAY

