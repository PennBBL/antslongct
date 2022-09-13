import ants 
import antspynet
import argparse
import sys
import os

parser = argparse.ArgumentParser()
parser.add_argument("-a", "--anatomical-image", help="Input anatomical image (T1w)", type=str, required=True)
parser.add_argument("-c", "--ct-image", help="Input cortical thickness image (T1w)", type=str, required=True)
parser.add_argument("-o", "--output-file", help="Output file", type=str,required = True)
args = parser.parse_args()

t1_file = args.anatomical_image
t1 = ants.image_read(t1_file)
ct_file = args.ct_image
ct = ants.image_read(ct_file)

# Desikan-Killiany-Tourville labeling

dkt = antspynet.desikan_killiany_tourville_labeling(t1, do_preprocessing=False,antsxnet_cache_directory = "/opt/dataCache/ANTsXNet")

# DKT label propagation throughout the cortex

dkt_cortical_mask = ants.threshold_image(dkt, 1000, 3000, 1, 0) 
dkt = dkt_cortical_mask * dkt 
ct_mask = ants.threshold_image(ct, 0, 0, 0, 1) 
dkt_propagated = ants.iMath(ct_mask, "PropagateLabelsThroughMask", ct_mask * dkt)

ants.image_write(dkt_propagated,args.output_file)
