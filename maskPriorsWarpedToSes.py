### This script creates a brain mask out of the priors warped to the SST
###
### Ellyn Butler
### February 24, 2021

import sys
import nibabel as nib
import numpy as np
import pandas as pd
import os
from copy import deepcopy

subj=sys.argv[1]
ses=sys.argv[2]

img = nib.load('/data/output/SegmentationPosteriors4_Normalizedto_'+subj+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz')
gmcort = img.get_fdata()
wmcort = nib.load('/data/output/SegmentationPosteriors6_Normalizedto_'+subj+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #6
csf = nib.load('/data/output/SegmentationPosteriors2_Normalizedto_'+subj+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #2
gmdeep = nib.load('/data/output/SegmentationPosteriors5_Normalizedto_'+subj+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #5
bstem = nib.load('/data/output/SegmentationPosteriors1_Normalizedto_'+subj+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #1
cereb = nib.load('/data/output/SegmentationPosteriors3_Normalizedto_'+subj+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #3

sum_arr = gmcort + wmcort + csf + gmdeep + bstem + cereb
sum_arr[sum_arr > 0] = 1

sum_img = nib.Nifti1Image(sum_arr, affine=img.affine)
sum_img.to_filename('/data/output/'+subj+'_'+ses+'_priorsMask.nii.gz')
