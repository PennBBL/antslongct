### This script calculates cortical thickness, volume and GMD in the DKT atlas
###
### Ellyn Butler
### March 2, 2021 - March 22, 2021

import os
import argparse
import numpy as np
import pandas as pd
import nibabel as nib
from nilearn.input_data import NiftiLabelsMasker

###############################################################################
############################   Parse arguments     ############################
###############################################################################

parser = argparse.ArgumentParser(
    description='Calculate volume, cortical thickness, and GMD by DKT region.')

parser.add_argument('-d', '--dkt', required=True,
                    help='full path to DKT labeled image')
parser.add_argument('-c', '--ct',
                    help='full path to cortical thickness image')
parser.add_argument('-g', '--gmd',
                    help='full path to gray matter density image')                    
parser.add_argument('-l', '--labels', 
                    default='/data/input/mindboggleCorticalLabels.csv',
                    help='full path to labels mapping csv')

args = parser.parse_args()

labels_path=args.labels
dkt_path=args.dkt
ct_path=args.ct
gmd_path=args.gmd

###############################################################################
############   Calculate volume of each DKT region, output csv.    ############
###############################################################################

# Get subject and session label from DKT image filename.
sub=os.path.basename(dkt_path).split("_")[0]
ses=os.path.basename(dkt_path).split("_")[1]

# Load DKT labeled T1w image.
dkt_img = nib.load(dkt_path)

# Read in DKT label csv to pandas dataframe.
label_df = pd.read_csv(labels_path)
label_df = label_df.rename(columns={"Label.ID": "LabelId", "Label.Name": "LabelName"})
label_ids = label_df.LabelId.values
label_names = label_df.LabelName.to_numpy() #dkt_df.LabelName.values
label_names = [name.replace('.', '_') for name in label_names]

# Get the voxel size (in mm3).
pixelDim = dkt_img.header['pixdim'][0:3]
voxelSize = np.prod(pixelDim)

# Calculate region volume for each DKT label.
dkt_array = dkt_img.get_fdata()
volume_values = [dkt_array[dkt_array == label_id].shape[0] * voxelSize for label_id in label_ids]

# Make values list for output df (subjectId, sessionId, + volume values list)
sub_ses = [sub.split('-')[1], ses.split('-')[1]]
volume_values = sub_ses + volume_values

# Make columns list for output df
columns = ['Subject Id', 'Session Id']
columns.extend(label_names)

# Combine columns and values into volume dataframe
volume_df = pd.DataFrame(data=[volume_values], columns=columns)

# Output volume dataframe to csv file
outDir = os.path.dirname(dkt_path)
volume_df.to_csv(outDir + '/' + sub + '_' + ses + '_Volume.csv', index=False)

###############################################################################
##### Optionally, calculate CT and GMD of each DKT region and output csv. #####
###############################################################################

# If either CT or GMD image was provided, fit DKT labels.
if ct_path or gmd_path:
    # Fit DKT labels
    masker = NiftiLabelsMasker(dkt_img)
    masker.fit()

# If CT image was provided, also output csv of CT values by DKT region.
if ct_path:
    # Load cortical thickness image.
    ct_img = nib.load(ct_path)
    # Get cortical thickness values by DKT region.
    ct_values = masker.transform(ct_img)
    # Make values list for output df (subjectId, sessionId, + CT values list).
    ct_values = sub_ses + ct_values.tolist()[0]    
    # Combine columns and values into CT dataframe.
    ct_df = pd.DataFrame(data=[ct_values], columns=columns)
    # Output CT dataframe to csv file.
    ct_df.to_csv(outDir + '/' + sub + '_' + ses + '_CorticalThickness.csv', index=False)

# If CT image was provided, also output csv of GMD values by DKT region.
if gmd_path: 
    # Load GMD image.
    gmd_img = nib.load(gmd_path)
    # Get GMD values by DKT region.
    gmd_values = masker.transform(gmd_img)
    # Make values list for output df (subjectId, sessionId, + gmd values list).
    gmd_values = sub_ses + gmd_values.tolist()[0]
    # Combine columns and values into GMD dataframe.
    gmd_df = pd.DataFrame(data=[gmd_values], columns=columns)
    # Output GMD dataframe to csv file.
    gmd_df.to_csv(outDir + '/' + sub + '_' + ses + '_GMD.csv', index=False)
