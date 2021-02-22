### Average all of the tissue classication images in the group template space
### to create tissue class priors (divide by sum of the voxels if they are all
### non-zero, and do nothing otherwise)
###
### Ellyn Butler
### November 17, 2020 - February 4, 2021


import nibabel as nib
import numpy as np
import pandas as pd
import os
from copy import deepcopy
from numpy import inf

# List the masks in group template space
files = os.listdir('/data/output/')

tissues_dict = {'Brainstem':[], 'CSF':[], 'Cerebellum':[], 'GMCortical':[],
    'GMDeep':[], 'WMCortical':[]}

# Declare an empty array
masks = [file for file in files if 'Brainstem_binary_Normalizedto' in file]
mask = [file for file in masks if 'sub-' in file][0]
img = nib.load('/data/output/'+mask)
img_array = img.get_fdata()
tissue_sum = np.zeros(img_array.shape)

for tissue in tissues_dict.keys():
    masks = [file for file in files if tissue+'_binary_Normalizedto' in file]
    projectName = masks[0].split('_')[4].split('.')[0].replace('Normalizedto', '').replace('Template', '')
    masks_array = []
    for mask in masks:
        img = nib.load('/data/output/'+mask)
        img_array = img.get_fdata()
        masks_array.append(img_array)
    tissues_dict[tissue] = np.sum(masks_array, axis=0)
    tissue_sum = tissue_sum + tissues_dict[tissue]

for tissue in tissues_dict.keys():
    tissues_dict[tissue] = np.true_divide(tissues_dict[tissue], tissue_sum)
    tissues_dict[tissue][np.isnan(tissues_dict[tissue])] = 0
    mask_average = nib.Nifti1Image(tissues_dict[tissue], affine=img.affine)
    mask_average.to_filename('/data/output/'+tissue+'_Normalizedto'+projectName+'Template_averageMask.nii.gz')


#This should just be 0s and 1s:
#np.unique(tissues_dict['Brainstem'] + tissues_dict['CSF'] + tissues_dict['Cerebellum'] + tissues_dict['GMCortical'] + tissues_dict['GMDeep'] + tissues_dict['WMCortical'])
