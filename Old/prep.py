### This script performs all steps on the SST prior to cortical thickness estimation
###
### Ellyn Butler
### February 1, 2021

import argparse
import ants
import sys

data_cache_dir = '/opt/dataCache/ANTsXNet'

parser = argparse.ArgumentParser(description='Prep priors for T1w image')

parser.add_argument('--g', dest='gtmp', metavar='N', type=str,
    nargs=1, help='Group template', required=True)

parser.add_argument('--s', dest='sst', metavar='N', type=str,
    nargs=1, help='Single subject template', required=True)

parser.add_argument('--p', dest='priors', metavar='N', type=list,
    nargs='+', help='Priors for the six tissue classes', required=True)

gtmp = ants.image_read(gtmp)
sst = ants.image_read(sst)
priors2 = [] # strings of tissue classes
for prior in priors:
    tissue = prior.split('/')[4].split('_')[0]
    priors2.append(tissue)
    img = ants.image_read(prior)
    exec(tissue+' = '+img)

### Compute warp from group template to SST
warp_gtmp_to_sst = ants.registration(sst, gtmp)

### Warp priors in group template space to SST space
for tissue in tissues:
    prior = eval(tissue)
    tissue_sst = ants.apply_transforms(sst, prior, warp_gtmp_to_sst)

### Write out transform list in the same manner as the binaries

### Perform Atropos on SST... might have to do in bash in order to specify priors
atropos = antspynet.deep_atropos(sst, do_preprocessing=False,
    antsxnet_cache_directory=data_cache_dir, verbose=True)

### Use output of Atropos on the SST as priors for cortical thickness estimation (?)
### on T1w image
