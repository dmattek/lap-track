# Call R script that combines files with 1-line header

#!/bin/bash

DIR=/opt/local/misc-improc/lap-track

Rscript $DIR/combine1lineHeaderOutput.R $@
