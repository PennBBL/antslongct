InDir=/data/input
OutDir=/data/output


# Bind
# 1.) Group template directory (template, priors and DKT labels needed)
# 2.) Single subject template directory directory (SST and padded/scaled T1w images needed)
# 3.) Output directory

sst=`find ${InDir}/sub* -name "*template0.nii.gz"`
subj=`echo ${sst} | cut -d "/" -f 5 | cut -d "_" -f 1`
gtmp=`find ${InDir}/version*/ -name "*template0.nii.gz"`

### Prep priors for T1w image
/scripts/prep.py --group ${gtmp} -sst ${sst}

### Get cortical thickness
for ses in ${sessions}; do
  python /opt/bin/do_antsxnet_thickness.py -a ${sst} -o ${OutDir}/${subj}_${ses}_ -t 1 ;
done

### Warp DKT labels from the group template space to the T1w space

### Create a mask out of the cortical thickness image

### Take the intersection of the cortical thickness mask and the DKT label
### image to get labels that conform to gray matter

### Get average cortical thickness of each region

### Get volume of each region

### Get averge GMD of each region (Atropos image for GMCortical)







#warp group to SST (to get tissue class priors in SST space), do atropos on SST,
# use output as priors for T1w images (closest to standard pipeline)
