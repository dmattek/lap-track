#!/bin/bash

# Clean LAP tracking output

# remove "track" directory created by MATLAB sript
find . -name "track*" -type d -exec rm -r {} +

# remove final "clean tracks" csv created by R script
find . -name "*clean_track*" -type f -exec rm -r {} +

# remove 1-line header CP output created by R script
find . -name "*1line.csv" -type f -exec rm -r {} +

# remove pngs with overlaid track IDs created by python script
find . -name "*over" -type d  -exec rm -r {} +
