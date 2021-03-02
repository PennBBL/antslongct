export ANTSPATH=/opt/ants/bin/
export PATH=${ANTSPATH}:$PATH
export LD_LIBRARY_PATH=/opt/ants/lib

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
if [ -f ${compwarp} ]; then
  warpSSTToGroupTemplate=`find ${VersionDir}/ -name "${projectName}Template_${subj}_template*Warp.nii.gz" -not -name "*Inverse*"`
  affSSTToGroupTemplate=`find ${VersionDir}/ -name "${projectName}Template_${subj}_template*Affine.mat" -not -name "*Inverse*"`
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
    warpSesToSST=`find ${InDir}/${subj}/ses-${ses}/ -name "*padscale*Warp.nii.gz" -not -name "*Inverse*"`;
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
#priors=`find ${grpdir} -name "*Template_prior.nii.gz"` #???
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
python /scripts/maskPriorsWarpedToSST.py ${subj}
groupMaskInSST=`find ${OutDir} -name "${subj}_priorsMask.nii.gz"`

### Copy priors to simpler name
cp ${OutDir}/BrainstemPrior_Normalizedto_${subj}_template.nii.gz ${OutDir}/prior1.nii.gz
cp ${OutDir}/CSFPrior_Normalizedto_${subj}_template.nii.gz ${OutDir}/prior2.nii.gz
cp ${OutDir}/CerebellumPrior_Normalizedto_${subj}_template.nii.gz ${OutDir}/prior3.nii.gz
cp ${OutDir}/GMCorticalPrior_Normalizedto_${subj}_template.nii.gz ${OutDir}/prior4.nii.gz
cp ${OutDir}/GMDeepPrior_Normalizedto_${subj}_template.nii.gz ${OutDir}/prior5.nii.gz
cp ${OutDir}/WMCorticalPrior_Normalizedto_${subj}_template.nii.gz ${OutDir}/prior6.nii.gz

### Perform Atropos on SST, using custom priors #NOT TESTED (weight = .25)
# Specifying priors not working
antsAtroposN4.sh -d 3 -a ${sst} -x ${groupMaskInSST} -c 6 -o ${OutDir}/${subj}_ \
  -w .25 -p ${OutDir}/prior%d.nii.gz

### Delete priors with simpler name
rm ${OutDir}/prior*.nii.gz

### Warp posteriors in SST space to T1w (ses) space
posteriors=`find ${OutDir} -name "${subj}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`
for ses in ${sessions}; do
  warpSSTtoSes=`find ${InDir}/${subj}/ses-${ses}/ -name "*InverseWarp.nii.gz"`
  affSestoSST=`find ${InDir}/${subj}/ses-${ses}/ -name "*_desc-preproc_T1w_padscale*Affine.txt"`
  for post in ${posteriors}; do
    warpedname=`echo ${post} | cut -d "/" -f 4 | cut -d "_" -f 2 | cut -d "." -f 1`
    warpedname=${warpedname}_Normalizedto_${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz
    antsApplyTransforms \
      -d 3 -e 0 -i ${post} \
      -o [${OutDir}/${warpedname},0] \
      -r ${InDir}/${subj}/ses-${ses}/${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz \
      -t ${warpSSTtoSes} \
      -t [${affSestoSST},1]
  done
done


### Use output of Atropos on the SST as priors Atropos on sessions (weight = .5) #NOT TESTED
### Get cortical thickness (feed in hard segmentation for Atropos on session) #NOT FUNCTIONING
for ses in ${sessions}; do
  python /scripts/maskPriorsWarpedToSes.py ${subj} ses-${ses}
  groupMaskInSes=${OutDir}/${subj}_ses-${ses}_priorsMask.nii.gz
  ### Copy posteriors to simpler name
  cp ${OutDir}/SegmentationPosteriors1_Normalizedto_${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/prior1.nii.gz
  cp ${OutDir}/SegmentationPosteriors2_Normalizedto_${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/prior2.nii.gz
  cp ${OutDir}/SegmentationPosteriors3_Normalizedto_${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/prior3.nii.gz
  cp ${OutDir}/SegmentationPosteriors4_Normalizedto_${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/prior4.nii.gz
  cp ${OutDir}/SegmentationPosteriors5_Normalizedto_${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/prior5.nii.gz
  cp ${OutDir}/SegmentationPosteriors6_Normalizedto_${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/prior6.nii.gz
  # Atropos on session
  antsAtroposN4.sh -d 3 -a ${InDir}/${subj}/ses-${ses}/${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz \
    -x ${groupMaskInSes} -c 6 -o ${OutDir}/${subj}_ses-${ses}_ -w .5 \
    -p ${OutDir}/prior%d.nii.gz
  # Delete priors with simpler name
  rm ${OutDir}/prior*.nii.gz
  # Run cortical thickness
  t1w=${InDir}/${subj}/ses-${ses}/${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz
  seg=${OutDir}/${subj}_ses-${ses}_Segmentation.nii.gz
  sespost=`find ${OutDir} -name "${subj}_ses-${ses}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`
  mkdir ${OutDir}/ses-${ses}
  python /opt/bin/do_antsxnet_thickness.py -a ${t1w} -s ${seg} -p ${sespost} -o ${OutDir}/ses-${ses}/${subj}_ses-${ses}_ -t 1 ;
done

### Warp DKT labels from the group template space to the T1w space #NOT TESTED
for ses in ${sessions}; do
  t1w=${InDir}/${subj}/ses-${ses}/${subj}_ses-${ses}_desc-preproc_T1w_padscale.nii.gz
  # Calculate the composite inverse warp
  warpSSTToSes=`find ${InDir}/${subj}/ses-${ses}/ -name "*padscale*InverseWarp.nii.gz"`;
  affSesToSST=`find ${InDir}/ -name "${subj}_ses-${ses}_desc-preproc_T1w_padscale*Affine.txt"`;
  warpGroupTemplateToSST=`find ${OutDir} -name "${subj}_NormalizedtoExtraLongTemplate_*InverseWarp.nii.gz"`
  antsApplyTransforms \
    -d 3 \
    -e 0 \
    -o [${OutDir}/ses-${ses}/${subj}_ses-${ses}_Normalizedto${projectName}TemplateCompositeInverseWarp.nii.gz, 1] \
    -r ${grpdir}/${projectName}Template_template0.nii.gz \
    -t [${affSesToSST}, 1] \
    -t ${warpSSTToSes} \
    -t ${warpGroupTemplateToSST} \
    -t [${affSSTToGroupTemplate}, 1]
  # Transform labels from group template to t1w space
  antsApplyTransforms \
    -d 3 -e 0 -n Multilabel \
    -i ${VersionDir}/${projectName}Template_malfLabels.nii.gz \
    -o [${OutDir}/ses-${ses}/${subj}_ses-${ses}_DKT.nii.gz, 0] \
    -r ${t1w} \
    -t ${OutDir}/ses-${ses}/${subj}_ses-${ses}_Normalizedto${projectName}TemplateCompositeInverseWarp.nii.gz
done

### Create a mask out of the cortical thickness image

### Take the intersection of the cortical thickness mask and the DKT label
### image to get labels that conform to gray matter

### Get average cortical thickness of each region

### Get volume of each region

### Get averge GMD of each region (Atropos image for GMCortical)
#https://github.com/PennBBL/xcpEngine/blob/master/modules/gmd/gmd.mod





# Move files to session directories
for ses in ${sessions}; do
  mv ${OutDir}/*ses-${ses}*.nii.gz ${OutDir}/ses-${ses}
done








#warp group to SST (to get tissue class priors in SST space), do atropos on SST,
# use output as priors for T1w images (closest to standard pipeline)
