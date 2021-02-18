InDir=/data/input
OutDir=/data/output


projectName=ExtraLong #FOR TESTING

# Bind
# 1.) Group template directory (template, priors and DKT labels needed)
# 2.) Single subject template directory directory (SST and padded/scaled T1w images needed)
# 3.) Output directory

sst=`find ${InDir}/sub* -name "*template0.nii.gz"`
subj=`echo ${sst} | cut -d "/" -f 5 | cut -d "_" -f 1`
grpdir=`find ${InDir} -type d -name "version*"`
gtmp=`find ${grpdir} -name "*template0.nii.gz"`
sessions=`find ${InDir}/${subj}/ -type d -name "ses-*" | cut -d "-" -f 3`

### Prep priors for T1w image
#priors=`find ${grpdir} -name "*Template_averageMask.nii.gz"`
#/scripts/prep.py --g ${gtmp} --s ${sst} --p ${priors}

### If the composite warp doesn't already exist, compute warp from group template to SST and the composite warp
### else, copy the composite warp into the output directory
for ses in ${sessions}; do
  VersionDir=`find ${InDir} -type d -name "version*"`
  compwarp="${VersionDir}/SST/${subj}_ses-${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz"
  warpSubToGroupTemplate=`find ${VersionDir}/ -name "${projectName}Template_${subj}_template*Warp.nii.gz" -not -name "*Inverse*"`;
  affSubToGroupTemplate=`find ${VersionDir}/ -name "${projectName}Template_${subj}_template*Affine.mat" -not -name "*Inverse*"`;
  if [ -f ${compwarp} ]; then
    cp ${compwarp} ${OutDir};
    cp ${warpSubToGroupTemplate} ${OutDir};
    cp ${affSubToGroupTemplate} ${OutDir};
  else
    # Calculate warp from SST to group
    antsRegistrationSyN.sh -d 3 -f ${VersionDir}/${projectName}Template_template0.nii.gz \
      -m ${InDir}/${subj}/${subj}_template0.nii.gz \
      -o ${OutDir}/${projectName}Template_
    warpSubToGroupTemplate=`find ${OutDir}/ -name "${projectName}Template_${subj}_template*Warp.nii.gz" -not -name "*Inverse*"`;
    affSubToGroupTemplate=`find ${OutDir}/ -name "${projectName}Template_${subj}_template*Affine.mat" -not -name "*Inverse*"`;
    warpSubToSST=`find ${InDir}/${subj}/ses-${ses}/ -name "*Warp.nii.gz" -not -name "*Inverse*"`
    affSubToSST=`find ${InDir}/ -name "${subj}_ses-${ses}_desc-preproc_T1w*Affine.txt"`;
    # And composite
    antsApplyTransforms \
      -d 3 \
      -e 0 \
      -o [${OutDir}/${subj}_ses-${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz, 1] \
      -r ${OutDir}/${projectName}Template_template0.nii.gz \
      -t ${warpSubToGroupTemplate} \
      -t ${affSubToGroupTemplate} \
      -t ${warpSubToSST} \
      -t ${affSubToSST}
  fi
done


### Calculate the composite warp from group template space to each T1w space,
### if they don't already exist

### Warp priors in group template space to SST space
priors=`find ${grpdir} -name "*Template_averageMask.nii.gz"`
for prior in ${priors}; do

done

### Perform Atropos on SST

### Use output of Atropos on the SST as priors for cortical thickness estimation (?)
### on T1w image

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
