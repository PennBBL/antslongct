### This script creates a brain mask out of the priors warped to the SST
###
### Ellyn Butler
### March 2, 2021

import sys
import nibabel as nib
import numpy as np

sub=sys.argv[1] #e.g. sub-113054
ses=sys.argv[2] #e.g. ses-PNC1
ses_dir=f"/data/output/subjects/{sub}/sessions/{ses}"
img = nib.load(f"{ses_dir}/{sub}_{ses}_CorticalThickness.nii.gz")
cort_array = img.get_fdata()

cort_array[cort_array > 0] = 1

cort_img = nib.Nifti1Image(cort_array, affine=img.affine)
cort_img.to_filename(f"{ses_dir}/{sub}_{ses}_CorticalThickness-mask.nii.gz")
