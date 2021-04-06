### This script calculates cortical thickness, volume and GMD in the DKT atlas
###
### Ellyn Butler
### March 2, 2021 - March 22, 2021

import sys
#from nilearn.input_data import NiftiLabelsMasker
#import numpy as np
#from scipy.stats import rankdata
#from scipy import signal
import nibabel as nib
#from templateflow.api import get as get_template
import pandas as pd
#from nipy import mindboggle
#sys.path.append('/scripts')
#from mindboggle import *
import numpy as np
#from scipy.spatial.distance import pdist, squareform
import nilearn
from nilearn.input_data import NiftiLabelsMasker

#latest = etelemetry.get_project("nipy/mindboggle")

sub=sys.argv[1] #sub='sub-113054'
ses=sys.argv[2] #ses='ses-PNC1'
sublabel=sys.argv[3] #sublabel='bblid'

atlas = nib.load('/data/output/'+ses+'/'+sub+'_'+ses+'_DKTIntersection.nii.gz')
#masker = NiftiLabelsMasker(labels_img=atlas, smoothing_fwhm=None, standardize=False)

cort = nib.load('/data/output/'+ses+'/'+sub+'_'+ses+'_CorticalThickness.nii.gz')
gmd = nib.load('/data/output/'+ses+'/'+sub+'_'+ses+'_GMD.nii.gz')

dkt_df = pd.read_csv('/data/input/mindboggleCorticalLabels.csv')

dkt_df = dkt_df.rename(columns={"Label.ID": "LabelID", "Label.Name": "LabelName"})
ints = dkt_df.LabelID.values
names = dkt_df.LabelName.to_numpy() #dkt_df.LabelName.values
names = [name.replace('.', '_') for name in names]

# Get the voxel size (mm3)
pixdim = atlas.header['pixdim'][0:3]
voxsize = np.prod(pixdim)

# Calculate volume
atlas_array = atlas.get_fdata()
volvals = [atlas_array[atlas_array == int].shape[0]*voxsize for int in ints]

masker = NiftiLabelsMasker('/data/output/'+ses+'/'+sub+'_'+ses+'_DKTIntersection.nii.gz')
masker.fit()
cortvals = masker.transform('/data/output/'+ses+'/'+sub+'_'+ses+'_CorticalThickness.nii.gz')
gmdvals = masker.transform('/data/output/'+ses+'/'+sub+'_'+ses+'_GMD.nii.gz')

vol_names = ['mprage_jlf_vol_'+name for name in names]
cort_names = ['mprage_jlf_ct_'+name for name in names]
gmd_names = ['mprage_jlf_gmd_'+name for name in names]

colnames = [sublabel, 'seslabel']
colnames.extend(vol_names)
colnames.extend(cort_names)
colnames.extend(gmd_names)

vals = [sub.split('-')[1], ses.split('-')[1]]
vals.extend(volvals)
vals.extend(cortvals.tolist()[0])
vals.extend(gmdvals.tolist()[0])
out_df = pd.DataFrame(data=[vals], columns=colnames)

out_df.to_csv('/data/output/'+ses+'/'+sub+'_'+ses+'_struc.csv', index=False)
