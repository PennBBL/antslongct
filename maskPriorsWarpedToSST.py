### This script creates a brain mask out of the priors warped to the SST
###
### Ellyn Butler
### February 22, 2021

import sys
import nibabel as nib
import numpy as np
import pandas as pd
import os
from copy import deepcopy

sub=sys.argv[1]

img = nib.load('/data/output/GMCorticalPrior_Normalizedto_'+sub+'_template.nii.gz')
gmcort = img.get_fdata()
wmcort = nib.load('/data/output/WMCorticalPrior_Normalizedto_'+sub+'_template.nii.gz').get_fdata()
csf = nib.load('/data/output/CSFPrior_Normalizedto_'+sub+'_template.nii.gz').get_fdata()
gmdeep = nib.load('/data/output/GMDeepPrior_Normalizedto_'+sub+'_template.nii.gz').get_fdata()
bstem = nib.load('/data/output/BrainstemPrior_Normalizedto_'+sub+'_template.nii.gz').get_fdata()
cereb = nib.load('/data/output/CerebellumPrior_Normalizedto_'+sub+'_template.nii.gz').get_fdata()

sum_arr = gmcort + wmcort + csf + gmdeep + bstem + cereb
sum_arr[sum_arr > 0] = 1

sum_img = nib.Nifti1Image(sum_arr, affine=img.affine)
sum_img.to_filename('/data/output/'+sub+'_priorsMask.nii.gz')
