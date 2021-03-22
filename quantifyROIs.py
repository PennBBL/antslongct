### This script calculates cortical thickness, volume and GMD in the DKT atlas
###
### Ellyn Butler
### March 2, 2021

import sys
#from nilearn.input_data import NiftiLabelsMasker
#import numpy as np
#from scipy.stats import rankdata
#from scipy import signal
import nibabel as nib
#from templateflow.api import get as get_template
#sys.path.append('/scripts')
import pandas as pd
#from nipy import mindboggle
from mindboggle import *
import numpy as np
#from scipy.spatial.distance import pdist, squareform
import nilearn.image as nim

#latest = etelemetry.get_project("nipy/mindboggle")

sub=sys.argv[1] #sub='sub-113054'
ses=sys.argv[2] #ses='ses-PNC1'

atlas = nib.load('/data/output/'+ses+'/'+sub+'_'+ses+'_DKTIntersection.nii.gz')
#masker = NiftiLabelsMasker(labels_img=atlas, smoothing_fwhm=None, standardize=False)

cort = nib.load('/data/output/'+ses+'/'+sub+'_'+ses+'_CorticalThickness.nii.gz')
gmd = nib.load('/data/output/'+ses+'/'+sub+'_'+ses+'_CorticalThickness.nii.gz')

dkt_df = pd.read_csv('/data/input/mindboggleCorticalLabels.csv')

dkt_df = dkt_df.rename(columns={"Label.ID": "LabelID", "Label.Name": "LabelName"})
ints = dkt_df.LabelID
names = dkt_df.LabelName

volvals = volume_per_brain_region(atlas, include_labels=ints, exclude_labels=[0],
                            label_names=names, save_table=False,
                            output_table='', verbose=False)

masker = NiftiLabelsMasker('/data/output/'+ses+'/'+sub+'_'+ses+'_DKTIntersection.nii.gz')
cortvals = masker.transform('/data/output/'+ses+'/'+sub+'_'+ses+'_CorticalThickness.nii.gz')
gmdvals = masker.transform('/data/output/'+ses+'/'+sub+'_'+ses+'_GMD.nii.gz')
