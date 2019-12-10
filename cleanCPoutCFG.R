# Cleans 2-line header output from CP
# Converts to a 1-line header
# Removes selected columns based on a config file provided as an argument
#
# Example call from the command-line
# Rscript cleanCPoutCFG.R lapconfig.csv
# 
# The lapconfig.csv should contain two columns with a header.
# The 1st column should contain parameter name.
# The 2nd column should contain parameter value.
#
# Parameter used from the config file:
# clean_cols - a string (in quotes) with comma-separated column names for removal from the original csv data file, e.g. clean_cols, "Image_Metadata_C,Image_Metadata_Channel"

require(data.table)

## Read command line params ----

args <- commandArgs(TRUE)

par = list()

# Path to config csv file
par$s.f.cfg = args[1]

# Path to working directory
par$s.wd = args[2]

if(sum(is.na(c(par$s.f.cfg, par$s.wd))) > 0L) {
  stop('Wrong number of parameters! Call: Rscript cleanCPoutCFG.R config_file path_to_wd')
}

## Parameter defs ----
# name of the parameter with columns for removal
par$cfg.file_cpout = 'file_cpout'
par$cfg.file_cpout_1line = "file_cpout_1line"
par$cfg.clean_cols = "clean_cols"
par$csvext = '.csv'
par$nsignif = 6L


## Custom functions ----
LOCfreadCSV2lineHeader = function(in.file, in.col.rem = NULL) {
  require(data.table)
  
  # check if the file is properly formatted and if it contains data
  # empty files (only with 2-line header) are gnererated by CP when no object identfied
  
  
  # Read the first two rows
  outFread = tryCatch(
    {
      loc.dt.head = data.table::fread(in.file, nrows = 2, header = FALSE)
    },
    
    error = function(cond) {
      message(sprintf("data.table::fread error. File %s is empty; return NULL", in.file))
      return(NULL)
    },
    
    warning = function(cond) {
      message(sprintf("data.table::fread warning File %s is empty; return NULL", in.file))
      return(NULL)
    },
    
    finally = function(cond) {
      return(loc.dt.nuc)
    }
  )
  
  if(is.null(outFread))
    return(NULL)
  
  # make a joint single-row header from two rows
  loc.s.head = paste0(loc.dt.head[1,], '_', loc.dt.head[2,])
  
  # read the rest of the output (except first two rows)
  outFread = tryCatch(
    {
      loc.dt.nuc = data.table::fread(in.file, skip = 2)
    },
    
    error = function(cond) {
      message(sprintf("data.table::fread error. File %s contains header but no content; return NULL", in.file))
      return(NULL)
    },
    
    finally = function(cond) {
      return(loc.dt.nuc)
    }
  )
  
  if(is.null(outFread))
    return(NULL)
  
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

# keep desired number of significant digits in a data.table
LOCsignif_dt <- function(dt, digits) {
  loc.dt = copy(dt)
  
  loc.cols <- vapply(loc.dt, is.double, FUN.VALUE = logical(1))
  loc.cols = names(loc.cols[loc.cols])
  
  loc.dt[, (loc.cols) := signif(.SD, digits), .SDcols = loc.cols]
  
  return(loc.dt)
}

#' Check whether a string consists only from digits
#'
#' @param x Input string
#'
#' @return True if the input string consists only from digits, False otherwise.
#' @export
#'
#' @examples
#' checkDigits('1111')
#' checkDigits('1111cccc')
LOCcheckDigits <- function(x) {
  grepl('^[-]?[0-9]+[.]?[0-9]*$' , x)
}

#' Check whether a string matches TRUE/FALSE, T/F, or T.../F...
#'
#' @param x Input string
#'
#' @return True if the input string matches the pattern, False otherwise.
#' @export
#'
#' @examples
#' checkLogical('TRUE')
#' checkLogical('xxxTxxx')
LOCcheckLogical <- function(x) {
  grepl('^TRUE$|^FALSE$|^T$|^F$' , x)
}



#' Converts string elements of a named list to apporpriate types
#'
#' Strings that consist of digits are converted to type \code{numeric}, strings with TRUE/FALSE, T/F, or T.../F... to \code{logical}.
#'
#' @param in.l Named list fo strings.
#'
#' @return Named list with elements converted to appropriate types.
#' @export
#'
#' @examples
#'  l.tst = list()
#'  l.tst$aaa = '1000'
#'  l.tst$bbb = '1000xx'
#'  l.tst$ccc = 'True'
#'  l.tst$ddd = 'xxxTrue'
#'  l.res = convertStringListToTypes(l.tst)
#'  str(l.res)

LOCconvertStringList2Types <- function(in.l) {
  # convert strings with digits to numeric
  # uses logical indexing: http://stackoverflow.com/questions/42207235/replace-list-elements-by-name-with-another-list
  loc.l = LOCcheckDigits(in.l)
  in.l[loc.l] = lapply(in.l[loc.l], as.numeric)
  
  # convert strings with TRUE/FALSE to logical
  loc.l = LOCcheckLogical(in.l)
  in.l[loc.l] = lapply(in.l[loc.l], as.logical)
  
  return(in.l)
}

## Read config file ----
# read the csv file; 2 columns only
dt.cfg = fread(par$s.f.cfg, select = 1:2)

# convert to a list
l.cfg = split(dt.cfg[[2]], dt.cfg[[1]])

# convert strings to appropriate types
l.cfg = LOCconvertStringList2Types(l.cfg)

# read a CSV with a 2-line header; 
# remove repeated columns; 
# remove columns according to the list in s.cols.rm


# check whether config file contains "file_cpout" paramater
if(par$cfg.file_cpout %in% names(l.cfg)) {
  par$file_cpout = l.cfg[[par$cfg.file_cpout]]
} else {
  stop(sprintf('Config file does not contain %s parameter, please provide!.', par$cfg.file_cpout))
}

# check whether config file contains "file_cpout_1line" paramater
if(par$cfg.file_cpout_1line %in% names(l.cfg)) {
  par$file_cpout_1line = l.cfg[[par$cfg.file_cpout_1line]]
} else {
  stop(sprintf('Config file does not contain %s parameter, please provide!.', par$cfg.file_cpout_1line))
}

# check whether config file contains "clean_cols" paramater
if(!(par$cfg.clean_cols %in% names(l.cfg))) {
  print(sprintf('Config file does not contain %s parameter; all columns kept.', par$cfg.clean_cols))
  par$clean_cols = NULL
} else {
  # split the string with (multiple) column names to remove into a list of strings
  par$clean_cols = unlist(strsplit(l.cfg[[par$cfg.clean_cols]], ','))
  print(sprintf("Removing columns: %s", par$clean_cols))
}

## Process ----
# read data csv with a 2-line header, remove columns in s.cols.rm
dt = LOCfreadCSV2lineHeader(file.path(par$s.wd, par$file_cpout), par$clean_cols)


## Write ----
# save file; no row numbers, no quotes around strings
write.csv(x = LOCsignif_dt(dt, par$nsignif), 
          file = file.path(par$s.wd, par$file_cpout_1line), row.names = F, quote = F)
