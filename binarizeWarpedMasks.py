### This script binarizes the tissue class masks that have been warped to the
### group template space
###
### Ellyn Butler
### February 3, 2021

import nibabel as nib
import numpy as np
import pandas as pd
import os
from copy import deepcopy

# List the available aseg images
files = os.listdir('/data/output/')
warpedmasks = [file for file in files if '_mask_NormalizedtoExtraLongTemplate.nii.gz' in file]

for wmask in warpedmasks:
    mask_img = nib.load('/data/output/'+wmask)
    mask_data = mask_img.get_fdata()
    mask_data[mask_data > .5] = 1.0
    mask_data[mask_data <= .5] = 0.0
    bin_mask_img = nib.Nifti1Image(mask_data, affine=mask_img.affine)
    bin_mask_img.to_filename('/data/output/'+wmask.replace('mask', 'binary'))
