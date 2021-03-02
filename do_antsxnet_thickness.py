import ants
import antspynet #not importing?
import argparse
import sys
import nibabel as nib
import numpy as np

import os.path
from os import path

import tensorflow as tf

# Script by Nick Tustison
# https://github.com/ntustison/PaperANTsX/blob/master/Data/Scripts/RunStudy/do_antsxnet_thickness.py
#https://antsx.github.io/ANTsPyNet/docs/build/html/utilities.html

parser = argparse.ArgumentParser()
parser.add_argument("-a", "--anatomical-image", help="Input anatomical image (T1w)", type=str, required=True)
parser.add_argument("-s", "--segmentation", help="Segmentation from Atropos", type=str, required=True)
parser.add_argument("-p", "--posteriors", help="Posteriors from Atropos on SST", nargs=6, type=str, required=True)
parser.add_argument("-o", "--output-prefix", help="Output prefix", type=str)
parser.add_argument("-t", "--threads", help="Number of threads in tensorflow operations. Use environment variable " \
                    "ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS to control threading in ANTs calls", type=int, default=1)
args = parser.parse_args()

# Internal variables for args
t1_file = args.anatomical_image #t1_file='/data/input/sub-113054/ses-PNC1/sub-113054_ses-PNC1_desc-preproc_T1w_padscale.nii.gz'
segmentation = args.segmentation #segmentation='/data/output/sub-113054_ses-PNC1_Segmentation.nii.gz'
posteriors = args.posteriors
# posteriors = ['/data/output/sub-113054_ses-PNC1_SegmentationPosteriors1.nii.gz',
# '/data/output/sub-113054_ses-PNC1_SegmentationPosteriors2.nii.gz', '/data/output/sub-113054_ses-PNC1_SegmentationPosteriors3.nii.gz',
# '/data/output/sub-113054_ses-PNC1_SegmentationPosteriors4.nii.gz', '/data/output/sub-113054_ses-PNC1_SegmentationPosteriors5.nii.gz',
# '/data/output/sub-113054_ses-PNC1_SegmentationPosteriors6.nii.gz']
output_prefix = args.output_prefix #output_prefix='/data/output/ses-PNC1/sub-113054_ses-PNC1_'
threads = args.threads #threads=1

# Cache data location. Data is stored inside the container to avoid downloads at run time
# which can fail in isolated cluster environments
data_cache_dir = "/opt/dataCache/ANTsXNet"

tf.keras.backend.clear_session()
config = tf.compat.v1.ConfigProto(intra_op_parallelism_threads=threads,
                                  inter_op_parallelism_threads=threads)
session = tf.compat.v1.Session(config=config) #2020-12-11 19:27:24.883689: W tensorflow/stream_executor/cuda/cuda_driver.cc:312] failed call to cuInit: UNKNOWN ERROR (303)
tf.compat.v1.keras.backend.set_session(session)

t1 = ants.image_read(t1_file)

# Recode values in segmentation image to match ANTs default
seg_img = nib.load(segmentation)
seg_array = seg_img.get_fdata()
seg_array = seg_array + 10
seg_array[seg_array == 10] = 0
seg_array[seg_array == 11] = 5
seg_array[seg_array == 12] = 1
seg_array[seg_array == 13] = 6
seg_array[seg_array == 14] = 2
seg_array[seg_array == 15] = 4
seg_array[seg_array == 16] = 3
seg_img = nib.Nifti1Image(seg_array, affine=seg_img.affine)
seg_img.to_filename(segmentation)

# Read in the recoded segmentation image
atropos_segmentation = ants.image_read(segmentation)

print("KellyKapowski")

kk_file = output_prefix + "CorticalThickness.nii.gz"
kk = None
if not path.exists(kk_file):
    #print("    Atropos:  calculating\n")
    #atropos = antspynet.deep_atropos(t1, do_preprocessing=True,
    #                                 antsxnet_cache_directory=data_cache_dir, verbose=True)
    #atropos_segmentation = atropos['segmentation_image']
    kk_segmentation = atropos_segmentation # Combine white matter and deep gray matter #TO DO: CHECK THESE VALUES SAME FOR MY IMAGE
    #kk_segmentation[kk_segmentation == 4] = 3 # Combine white matter and deep gray matter #TO DO: CHECK THESE VALUES SAME FOR MY IMAGE
    kk_segmentation[kk_segmentation == 4] = 3
    #kk_white_matter = atropos['probability_images'][3] + atropos['probability_images'][4]
    wm_prob = ants.image_read([s for s in posteriors if '_SegmentationPosteriors6.nii.gz' in s][0])
    dgm_prob = ants.image_read([s for s in posteriors if '_SegmentationPosteriors5.nii.gz' in s][0])
    kk_white_matter = wm_prob + dgm_prob
    cgm_prob = ants.image_read([s for s in posteriors if '_SegmentationPosteriors4.nii.gz' in s][0])
    #kk_white_matter = atropos['probability_images'][3] + atropos['probability_images'][4]
    print("    KellyKapowski:  calculating\n")
    kk = ants.kelly_kapowski(s=kk_segmentation, g=cgm_prob, w=kk_white_matter,
        its=45, r=0.025, m=1.5, t=10, x=0, verbose=1)
    #kk = ants.kelly_kapowski(s=kk_segmentation, g=atropos['probability_images'][2],
    #                         w=kk_white_matter, its=45, r=0.025, m=1.5, t=10, x=0, verbose=1)
    ants.image_write(kk, kk_file)
else:
    print("    Reading\n")
    kk = ants.image_read(kk_file)

# If one wants cortical labels one can run the following lines

#print("DKT\n")

#dkt_file = output_prefix + "Dkt.nii.gz"
#dkt = None
#if not path.exists(dkt_file):
#    print("    Calculating\n") #Brain extraction happens here
#    dkt = antspynet.desikan_killiany_tourville_labeling(t1, do_preprocessing=True,
#                                                        antsxnet_cache_directory=data_cache_dir, verbose=True)
#    ants.image_write(dkt, dkt_file)
#else:
#    print("    Reading\n")
#    dkt = ants.image_read(dkt_file)

#print("DKT Prop\n")

#dkt_prop_file = output_prefix + "DktPropagatedLabels.nii.gz"
#if not path.exists(dkt_prop_file):
#    print("    Calculating\n")
#    dkt_mask = ants.threshold_image(dkt, 1000, 3000, 1, 0)
#    dkt = dkt_mask * dkt
#    ants_tmp = ants.threshold_image(kk, 0, 0, 0, 1)
#    ants_dkt = ants.iMath(ants_tmp, "PropagateLabelsThroughMask", ants_tmp * dkt)
#    ants.image_write(ants_dkt, output_prefix + "DktPropagatedLabels.nii.gz")
#
os.system("cp -r /home/antspyuser/ /data/output/")
