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
VersionDir=`find ${InDir} -type d -name "version*"`
warpSSTToGroupTemplate=`find ${VersionDir}/ -name "${projectName}Template_${subj}_template*Warp.nii.gz" -not -name "*Inverse*"`
affSSTToGroupTemplate=`find ${VersionDir}/ -name "${projectName}Template_${subj}_template*Affine.mat" -not -name "*Inverse*"`
if [ -f ${compwarp} ]; then
  cp ${warpSSTToGroupTemplate} ${OutDir}/${subj}_Normalizedto${projectName}Template_Warp.nii.gz;
  cp ${affSSTToGroupTemplate} ${OutDir}/${subj}_Normalizedto${projectName}Template_Affine.mat;
else
  # Calculate warp from SST to group
  antsRegistrationSyN.sh -d 3 -f ${VersionDir}/${projectName}Template_template0.nii.gz \
    -m ${InDir}/${subj}/${subj}_template0.nii.gz \
    -o ${OutDir}/${subj}_Normalizedto${projectName}Template_
  warpSSTToGroupTemplate=`find ${OutDir}/ -name "${subj}_Normalizedto${projectName}Template_*Warp.nii.gz" -not -name "*Inverse*"`
  affSSTToGroupTemplate=`find ${OutDir}/ -name "${subj}_Normalizedto${projectName}Template_*Affine.mat" -not -name "*Inverse*"`
fi

for ses in ${sessions}; do
  compwarp="${VersionDir}/SST/${subj}_ses-${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz"
  if [ -f ${compwarp} ]; then
    cp ${compwarp} ${OutDir};
  else
    # Calculate composite warp
    warpSesToSST=`find ${InDir}/${subj}/ses-${ses}/ -name "*padscale*Warp.nii.gz" -not -name "*Inverse*"`
    affSesToSST=`find ${InDir}/ -name "${subj}_ses-${ses}_desc-preproc_T1w_padscale*Affine.txt"`;
    # Composite t1w space to group template space
    antsApplyTransforms \
      -d 3 \
      -e 0 \
      -o [${OutDir}/${subj}_ses-${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz, 1] \
      -r ${grpdir}/${projectName}Template_template0.nii.gz \
      -t ${warpSSTToGroupTemplate} \
      -t ${affSSTToGroupTemplate} \
      -t ${warpSesToSST} \
      -t ${affSesToSST};
  fi;
done

### Warp priors in group template space to SST space #antsApplyTransforms not working/NECESSARY??
priors=`find ${grpdir} -name "*Template_averageMask.nii.gz"`
warpGroupTemplatetoSST=`find ${OutDir} -name "${subj}_Normalizedto${projectName}Template_*InverseWarp.nii.gz"`
#affGroupTemplatetoSST=`find ${OutDir} -name "${subj}_Normalizedto${projectName}Template_*GenericAffine.mat"`
for prior in ${priors}; do
  tissue=`echo ${prior} | cut -d "/" -f 6 | cut -d "_" -f 1`;
  antsApplyTransforms \
    -d 3 -e 0 -i ${prior} \
    -o [${OutDir}/${tissue}Prior_Normalizedto_${subj}_template.nii.gz,0] \
    -r ${sst} \
    -t ${warpGroupTemplatetoSST} \
    -t [${affSSTToGroupTemplate},1]
done

### Create a mask out of all non-zero voxels of warped priors

groupMaskInSST=

### Perform Atropos on SST, using custom priors #NOT TESTED
antsAtroposN4.sh -d 3 -a ${sst} -x ${groupMaskInSST} -c 6 -o ${OutDir}/${subj}_ \
  -p ${OutDir}/%Prior_Normalizedto_${subj}_template.nii.gz

### Warp posteriors in SST space to T1w (ses) space
posteriors=
for post in ${posteriors}; do

done

### Use output of Atropos on the SST as priors for cortical thickness estimation (?)
### on T1w image

### Get cortical thickness #NOT FUNCTIONING
for ses in ${sessions}; do
  python /opt/bin/do_antsxnet_thickness.py -a ${sst} -o ${OutDir}/${subj}_${ses}_ -t 1 ;
done

### Warp DKT labels from the group template space to the T1w space #NOT TESTED
antsApplyTransforms \
  -d 3 -e 0 -n Multilabel \
  -o [${OutDir}/${subj}_ses-${ses}_DKT.nii.gz, 0] \
  -r ${OutDir}/${projectName}Template_template0.nii.gz \
  -t [${OutDir}/${subj}_ses-${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz, 1]

### Create a mask out of the cortical thickness image

### Take the intersection of the cortical thickness mask and the DKT label
### image to get labels that conform to gray matter

### Get average cortical thickness of each region

### Get volume of each region

### Get averge GMD of each region (Atropos image for GMCortical)







#warp group to SST (to get tissue class priors in SST space), do atropos on SST,
# use output as priors for T1w images (closest to standard pipeline)
