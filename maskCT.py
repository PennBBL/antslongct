### This script creates a brain mask out of the priors warped to the SST
###
### Ellyn Butler
### March 2, 2021

import sys
import nibabel as nib
import numpy as np

subj=sys.argv[1] #sub-113054
ses=sys.argv[2] #ses-PNC1

img = nib.load('/data/output/'+ses+'/'+subj+'_'+ses+'_CorticalThickness.nii.gz')
cort_array = img.get_fdata()

cort_array[cort_array > 0] = 1

cort_img = nib.Nifti1Image(cort_array, affine=img.affine)
cort_img.to_filename('/data/output/'+ses+'/'+subj+'_'+ses+'_CorticalThickness_mask.nii.gz')
