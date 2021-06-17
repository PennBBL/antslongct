### This script creates a brain mask out of the priors warped to the SST
###
### Ellyn Butler
### February 24, 2021
### March 26, 2021: ses dir

import sys
import nibabel as nib
import numpy as np
import pandas as pd
import os
from copy import deepcopy

sub=sys.argv[1]
ses=sys.argv[2]

img = nib.load('/data/output/'+ses+'/SegmentationPosteriors4_Normalizedto_'+sub+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz')
gmcort = img.get_fdata()
wmcort = nib.load('/data/output/'+ses+'/SegmentationPosteriors6_Normalizedto_'+sub+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #6
csf = nib.load('/data/output/'+ses+'/SegmentationPosteriors2_Normalizedto_'+sub+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #2
gmdeep = nib.load('/data/output/'+ses+'/SegmentationPosteriors5_Normalizedto_'+sub+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #5
bstem = nib.load('/data/output/'+ses+'/SegmentationPosteriors1_Normalizedto_'+sub+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #1
cereb = nib.load('/data/output/'+ses+'/SegmentationPosteriors3_Normalizedto_'+sub+'_'+ses+'_desc-preproc_T1w_padscale.nii.gz').get_fdata() #3

sum_arr = gmcort + wmcort + csf + gmdeep + bstem + cereb
sum_arr[sum_arr > 0] = 1

sum_img = nib.Nifti1Image(sum_arr, affine=img.affine)
sum_img.to_filename('/data/output/'+ses+'/'+sub+'_'+ses+'_priorsMask.nii.gz')
