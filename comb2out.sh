# Call R script that combines files with 2-line header

#!/bin/bash

DIR=/opt/local/misc-improc/lap-track

Rscript $DIR/combine2lineHeaderOutput.R $@
