### This script performs all steps on the SST prior to cortical thickness estimation
###
### Ellyn Butler
### February 1, 2021

import argparse
import ants
import sys

parser = argparse.ArgumentParser(description='Prep priors for T1w image')

parser.add_argument('--group', dest='gtmp', metavar='N', type=str,
    nargs=1, help='Group template')

parser.add_argument('--sst', dest='sst', metavar='N', type=str,
    nargs=1, help='Single subject template')

### Compute warp from group template to SST
ants.registration(sst, gtmp)

### Warp priors in group template space to SST space


### Perform Atropos on SST

### Use output of Atropos on the SST as priors for cortical thickness estimation (?)
### on T1w image
