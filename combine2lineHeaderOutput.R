# Searches for csv files in all sub-directories of a given directory, merges the files
# and puts them in specified output directory.
# Files for merging should have a 2-line-header
#
# Example call from the command-line
# Rscript combine2lineHeaderOutput.R ~/myexp1/cp.out/output objNuc.csv .mer
# Last parameter is optional, defaults to ".mer"

require(data.table)
require(optparse)
require(R.utils)

#' Read a CSV file with a 2-line header
#'
#' A CSV file with a 2-line header is frequently output by CellProfiler when merging separate object outputs is set
#' in ExportToSpreadsheet module. The output contains merged outputs from different objects (e.g. cytosol, nucleus),
#' which means that the header consists of 2 lines, first with object name, second with the measurement name.
#' These two lines are merged in this function.
#'
#' @param in.file Name of the CSV file.
#' @param in.col.rem String vector with column names to remove, default NULL.
#'
#' @return Data table with column names set according to 2 first lines of the header, i.e. merged with '_'.
#' @export
#' @import data.table

LOCfreadCSV2lineHeader = function(in.file, in.col.rem = NULL) {


  # Read the first two rows
  loc.dt.head = data.table::fread(in.file, nrows = 2, header = FALSE)

  # make a joint single-row header from two rows
  loc.s.head = paste0(loc.dt.head[1,], '_', loc.dt.head[2,])

  # read the rest of the output (except first two rows)
  loc.dt.nuc = data.table::fread(in.file, skip = 2)

  # set column names
  data.table::setnames(loc.dt.nuc, loc.s.head)

  # remove duplicated columns
  loc.dt.nuc = loc.dt.nuc[, loc.s.head[!duplicated(loc.s.head)], with = FALSE]

  # check whether the list of columns to remove provided as the f-n parameter
  # contains column names in the data table
  if (!is.null(in.col.rem)) {
    loc.col.rem = intersect(loc.s.head, in.col.rem)

    # remove columns if the list isn't empty
    if (length(loc.col.rem) > 0)
      loc.dt.nuc[, (loc.col.rem) := NULL]
  }

  return(loc.dt.nuc)
}


# parser of command-line arguments from:
# https://www.r-bloggers.com/passing-arguments-to-an-r-script-from-command-lines/

option_list = list(
  make_option(c("-f", "--fileout"), type="character", default=NULL, 
              help="csv with 2-line header output [no default; e.g. objNuclei.csv]", metavar="character"),
  make_option(c("-o", "--dirout"), type="character", default="output", 
              help="directory with entire output [default= %default]", metavar="character"),
  make_option(c("-s", "--suffout"), type="character", default=".mer", 
              help="suffix to add to the output directory, to make directory with merged output [default= %default]", metavar="character"),
  make_option(c("-r", "--remcols"), type="character", default="", 
              help="quoted, no spaces, comma-separated list with column names to remove [default= %default; e.g. \"Image_Metadata_C,Image_Metadata_Z\"]", metavar="character"),
  make_option(c("-z", "--gzip"), action="store_true", default="FALSE",
              help="gzip the resulting csv [default= %default]")
);

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$fileout)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input fileout).n", call.=FALSE)
}

# params
params = list()

## User-defined input

# Path to CP output
# This directory is the root for a directory that contains sub-directories
# E.g. myexp1/cp.out1/output
params$s.dir.data = opt$dirout

# File name with CP output, e.g. objNuclei_1line_clean_tracks.csv
# This file will be searched in subdirectories of s.dir.data folder
params$s.file.data = opt$fileout

# Suffix to add to output directory name for placing merged output
# Default ".mer"
params$s.dir.suf = opt$suffout

# Create directory for merged output in the current working directory
# Directory with merged output has the same name as the root output directory but with params$s.file.suf suffix
# First remove trailing / from s.dir.data
params$s.dir.data = gsub('\\/$', '', params$s.dir.data)
params$s.dir.out = paste0(params$s.dir.data, params$s.dir.suf)
ifelse(!dir.exists(file.path(params$s.dir.out)), 
       dir.create(file.path(params$s.dir.out)), 
       FALSE)

# Create vector with columns to remove based on the input parameter
params$s.col.rem = unlist(strsplit(opt$remcols, ','))

# 
cat(sprintf("Processing data in: %s\n", params$s.dir.data))
cat(sprintf("Saving output to  : %s\n\n", file.path(params$s.dir.out, params$s.file.data)))
cat(sprintf("Removing columns  :\n %s\n\n", params$s.col.rem))


# store locations of all csv files in the output folder
s.files = list.files(path = file.path(params$s.dir.data), 
                     pattern = paste0(params$s.file.data, "$"),
                     recursive = TRUE, 
                     full.names = TRUE)
cat("Merging files:\n")
cat(s.files)
cat("\n")

dt.all = do.call(rbind, lapply(s.files, function(x) LOCfreadCSV2lineHeader(x, in.col.rem = params$s.col.rem)))

# write merged dataset
fwrite(dt.all, file = file.path(params$s.dir.out, params$s.file.data), row.names = F) 
if (opt$gzip) {
        cat("\nMerged file will be gzipped\n")
        gzip(file.path(params$s.dir.out, params$s.file.data))
}
