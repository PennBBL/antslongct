### This script creates gray matter, white matter and CSF masks for each of the
### input aseg dseg images.
###
### Ellyn Butler
### November 12, 2020 - February 8, 2021

import nibabel as nib
import numpy as np
import pandas as pd
import os
from copy import deepcopy

# List the available aseg images
files = os.listdir('/data/input/')
asegs = [file for file in files if 'aseg' in file]

# Read in tissue classes
tissue_df = pd.read_csv('/data/input/tissueClasses.csv')

# Loop over asegs, and create GM, WM and CSF images
for aseg in asegs:
    aseg_img = nib.load('/data/input/'+aseg)
    aseg_gmcort = aseg_img.get_fdata()
    aseg_wmcort = deepcopy(aseg_gmcort)
    aseg_csf = deepcopy(aseg_gmcort)
    aseg_gmdeep = deepcopy(aseg_gmcort)
    aseg_bstem = deepcopy(aseg_gmcort)
    aseg_cereb = deepcopy(aseg_gmcort)
    for i in tissue_df.Number:
        aseg_gmcort[aseg_gmcort == i] = tissue_df[tissue_df['Number'] == i].GMCortical.values[0]
        aseg_wmcort[aseg_wmcort == i] = tissue_df[tissue_df['Number'] == i].WMCortical.values[0]
        aseg_csf[aseg_csf == i] = tissue_df[tissue_df['Number'] == i].CSF.values[0]
        aseg_gmdeep[aseg_gmdeep == i] = tissue_df[tissue_df['Number'] == i].GMDeep.values[0]
        aseg_bstem[aseg_bstem == i] = tissue_df[tissue_df['Number'] == i].Brainstem.values[0]
        aseg_cereb[aseg_cereb == i] = tissue_df[tissue_df['Number'] == i].Cerebellum.values[0]
    if np.array_equal(np.unique(aseg_gmcort), np.array([0, 1])):
        print('All values in the aseg image have successfully been converted to 0 or 1')
    else:
        print('Oh no! There is a value in one of your aseg images that is not in tissueClasses.csv')
        break
    gmcort_img = nib.Nifti1Image(aseg_gmcort, affine=aseg_img.affine)
    wmcort_img = nib.Nifti1Image(aseg_wmcort, affine=aseg_img.affine)
    csf_img = nib.Nifti1Image(aseg_csf, affine=aseg_img.affine)
    gmdeep_img = nib.Nifti1Image(aseg_gmdeep, affine=aseg_img.affine)
    bstem_img = nib.Nifti1Image(aseg_bstem, affine=aseg_img.affine)
    cereb_img = nib.Nifti1Image(aseg_cereb, affine=aseg_img.affine)
    gmcort_img.to_filename('/data/output/'+aseg.replace('desc-aseg_dseg', 'GMCortical_mask'))
    wmcort_img.to_filename('/data/output/'+aseg.replace('desc-aseg_dseg', 'WMCortical_mask'))
    csf_img.to_filename('/data/output/'+aseg.replace('desc-aseg_dseg', 'CSF_mask'))
    gmdeep_img.to_filename('/data/output/'+aseg.replace('desc-aseg_dseg', 'GMDeep_mask'))
    bstem_img.to_filename('/data/output/'+aseg.replace('desc-aseg_dseg', 'Brainstem_mask'))
    cereb_img.to_filename('/data/output/'+aseg.replace('desc-aseg_dseg', 'Cerebellum_mask'))
