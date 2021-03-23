export ANTSPATH=/opt/ants/bin/
export PATH=${ANTSPATH}:$PATH
export LD_LIBRARY_PATH=/opt/ants/lib

InDir=/data/input
OutDir=/data/output


# Bind
# 1.) Group template directory (template, priors and DKT labels needed)
# 2.) Single subject template directory directory (SST and padded/scaled T1w images needed)
# 3.) Output directory

sst=`find ${InDir}/sub* -name "*template0.nii.gz"`
subj=`echo ${sst} | cut -d "/" -f 5 | cut -d "_" -f 1`
TemplateDir=`find ${InDir} -type d -name "antspriors*"`
gtmp=`find ${TemplateDir} -name "*template0.nii.gz"`
sessions=`find ${InDir}/${subj}/ -type d -name "ses-*" | cut -d "/" -f 5`

### Prep priors for T1w image
#priors=`find ${TemplateDir} -name "*Template_averageMask.nii.gz"`
#/scripts/prep.py --g ${gtmp} --s ${sst} --p ${priors}

### If the composite warp doesn't already exist, compute warp from group template to SST and the composite warp
### else, copy the composite warp into the output directory

for ses in ${sessions}; do
  compwarp="${TemplateDir}/SST/${subj}_${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz"
  if [ -f ${compwarp} ]; then
    warpSSTToGroupTemplate=`find ${TemplateDir}/ -name "${projectName}Template_${subj}_template*Warp.nii.gz" -not -name "*Inverse*"`
    affSSTToGroupTemplate=`find ${TemplateDir}/ -name "${projectName}Template_${subj}_template*Affine.mat" -not -name "*Inverse*"`
    cp ${warpSSTToGroupTemplate} ${OutDir}/${subj}_Normalizedto${projectName}Template_Warp.nii.gz;
    cp ${affSSTToGroupTemplate} ${OutDir}/${subj}_Normalizedto${projectName}Template_Affine.mat;
    cp ${compwarp} ${OutDir};
  else
    antsRegistrationSyN.sh -d 3 -f ${TemplateDir}/${projectName}Template_template0.nii.gz \
      -m ${InDir}/${subj}/${subj}_template0.nii.gz \
      -o ${OutDir}/${subj}_Normalizedto${projectName}Template_
    warpSSTToGroupTemplate=`find ${OutDir}/ -name "${subj}_Normalizedto${projectName}Template_*Warp.nii.gz" -not -name "*Inverse*"`
    affSSTToGroupTemplate=`find ${OutDir}/ -name "${subj}_Normalizedto${projectName}Template_*Affine.mat" -not -name "*Inverse*"`
    # Calculate composite warp
    warpSesToSST=`find ${InDir}/${subj}/${ses}/ -name "*padscale*Warp.nii.gz" -not -name "*Inverse*"`;
    affSesToSST=`find ${InDir}/ -name "${subj}_${ses}_desc-preproc_T1w_padscale*Affine.txt"`;
    # Composite t1w space to group template space
    antsApplyTransforms \
      -d 3 \
      -e 0 \
      -o [${OutDir}/${subj}_${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz, 1] \
      -r ${TemplateDir}/${projectName}Template_template0.nii.gz \
      -t ${warpSSTToGroupTemplate} \
      -t ${affSSTToGroupTemplate} \
      -t ${warpSesToSST} \
      -t ${affSesToSST};
  fi;
done

### Warp priors in group template space to SST space #antsApplyTransforms not working/NECESSARY??
#priors=`find ${TemplateDir} -name "*Template_prior.nii.gz"` #???
priors=`find ${TemplateDir} -name "*Template_prior.nii.gz"`
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

### Perform Atropos on SST, using custom priors (weight = .25)
# Specifying priors not working
antsAtroposN4.sh -d 3 -a ${sst} -x ${groupMaskInSST} -c 6 -o ${OutDir}/${subj}_ \
  -w .25 -p ${OutDir}/prior%d.nii.gz

### Delete priors with simpler name
rm ${OutDir}/prior*.nii.gz

### Warp posteriors in SST space to T1w (ses) space
posteriors=`find ${OutDir} -name "${subj}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`
for ses in ${sessions}; do
  mkdir ${OutDir}/${ses}
  warpSSTtoSes=`find ${InDir}/${subj}/${ses}/ -name "*InverseWarp.nii.gz"`
  affSestoSST=`find ${InDir}/${subj}/${ses}/ -name "*_desc-preproc_T1w_padscale*Affine.txt"`
  for post in ${posteriors}; do
    warpedname=`echo ${post} | cut -d "/" -f 4 | cut -d "_" -f 2 | cut -d "." -f 1`
    warpedname=${warpedname}_Normalizedto_${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz
    antsApplyTransforms \
      -d 3 -e 0 -i ${post} \
      -o [${OutDir}/${ses}/${warpedname},0] \
      -r ${InDir}/${subj}/${ses}/${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz \
      -t ${warpSSTtoSes} \
      -t [${affSestoSST},1]
  done
  ### Use output of Atropos on the SST as priors Atropos on sessions (weight = .5)
  ### Get cortical thickness (feed in hard segmentation for Atropos on session)
  python /scripts/maskPriorsWarpedToSes.py ${subj} ${ses}
  groupMaskInSes=${OutDir}/${subj}_${ses}_priorsMask.nii.gz
  ### Copy posteriors to simpler name
  cp ${OutDir}/${ses}/SegmentationPosteriors1_Normalizedto_${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior1.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors2_Normalizedto_${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior2.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors3_Normalizedto_${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior3.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors4_Normalizedto_${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior4.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors5_Normalizedto_${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior5.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors6_Normalizedto_${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior6.nii.gz
  # Atropos on session
  antsAtroposN4.sh -d 3 -a ${InDir}/${subj}/${ses}/${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz \
    -x ${groupMaskInSes} -c 6 -o ${OutDir}/${ses}/${subj}_${ses}_ -w .5 \
    -p ${OutDir}/${ses}/prior%d.nii.gz
  # Delete priors with simpler name
  rm ${OutDir}/${ses}/prior*.nii.gz
  # Run cortical thickness
  t1w=${InDir}/${subj}/${ses}/${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz
  seg=${OutDir}/${ses}/${subj}_${ses}_Segmentation.nii.gz
  cp ${seg} ${OutDir}/${ses}/${subj}_${ses}_Segmentation_old.nii.gz
  sespost=`find ${OutDir} -name "${subj}_${ses}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`
  # Copy cortical gray matter posteriors to GMD image
  cp ${OutDir}/${ses}/${subj}_${ses}_SegmentationPosteriors4.nii.gz ${OutDir}/${ses}/${subj}_${ses}_GMD.nii.gz
  # Run cortical thickness
  python /opt/bin/do_antsxnet_thickness.py -a ${t1w} -s ${seg} -p ${sespost} -o ${OutDir}/${ses}/${subj}_${ses}_ -t 1 ;

  ### Warp DKT labels from the group template space to the T1w space
  t1w=${InDir}/${subj}/${ses}/${subj}_${ses}_desc-preproc_T1w_padscale.nii.gz
  # Calculate the composite inverse warp
  warpSSTToSes=`find ${InDir}/${subj}/${ses}/ -name "*padscale*InverseWarp.nii.gz"`;
  affSesToSST=`find ${InDir}/ -name "${subj}_${ses}_desc-preproc_T1w_padscale*Affine.txt"`;
  warpGroupTemplateToSST=`find ${OutDir} -name "${subj}_NormalizedtoExtraLongTemplate_*InverseWarp.nii.gz"`
  antsApplyTransforms \
    -d 3 \
    -e 0 \
    -o [${OutDir}/${ses}/${subj}_${ses}_Normalizedto${projectName}TemplateCompositeInverseWarp.nii.gz, 1] \
    -r ${TemplateDir}/${projectName}Template_template0.nii.gz \
    -t [${affSesToSST}, 1] \
    -t ${warpSSTToSes} \
    -t ${warpGroupTemplateToSST} \
    -t [${affSSTToGroupTemplate}, 1]
  # Transform labels from group template to t1w space
  antsApplyTransforms \
    -d 3 -e 0 -n Multilabel \
    -i ${TemplateDir}/${projectName}Template_malfLabels.nii.gz \
    -o [${OutDir}/${ses}/${subj}_${ses}_DKT.nii.gz, 0] \
    -r ${t1w} \
    -t ${OutDir}/${ses}/${subj}_${ses}_Normalizedto${projectName}TemplateCompositeInverseWarp.nii.gz

  ### Quantify regional values
  ### Create a mask out of the cortical thickness image (try dividng by itself in ANTs - nope, puts in 1 for 0/0)
  #ImageMath 3 ${OutDir}/${ses}/${subj}_${ses}_CorticalThickness_mask.nii.gz TruncateImageIntensity ${OutDir}/${ses}/${subj}_${ses}_CorticalThickness.nii.gz binary-maskImage
  python /scripts/maskCT.py ${subj} ${ses} ${subLabel}
  ### Take the intersection of the cortical thickness mask and the DKT label
  ### image to get labels that conform to gray matter
  mask=${OutDir}/${ses}/${subj}_${ses}_CorticalThickness_mask.nii.gz
  imagename="${subj}_${ses}_DKTIntersection.nii.gz"
  ImageMath 3 ${OutDir}/${ses}/${imagename} m ${OutDir}/${ses}/${subj}_${ses}_DKT.nii.gz ${mask}
  ### Get cortical thickness, GMD and volume of each region
  #ImageMath 3 LabelStats ${OutDir}/${ses}/${subj}_${ses}_CorticalThickness.nii.gz ${OutDir}/${ses}/${subj}_${ses}_DKT.nii.gz

  python /scripts/quantifyROIs.py ${subj} ${ses}
  # Move files to session directories
  mv ${OutDir}/*${ses}*.nii.gz ${OutDir}/${ses}
  mv ${OutDir}/*${ses}*.txt ${OutDir}/${ses}
done

### GMD: https://github.com/PennBBL/xcpEngine/blob/master/modules/gmd/gmd.mod
