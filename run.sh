export ANTSPATH=/opt/ants/bin/
export PATH=${ANTSPATH}:$PATH
export LD_LIBRARY_PATH=/opt/ants/lib

InDir=/data/input
OutDir=/data/output

# Bind
# 1.) Group template directory (template, priors and DKT labels needed)
# 2.) Single subect template directory directory (SST and padded/scaled T1w images needed)
# 3.) Output directory

sst=`find ${InDir}/sub* -name "*template0.nii.gz"`
sub=`echo ${sst} | cut -d "/" -f 5 | cut -d "_" -f 1`
TemplateDir=`find ${InDir} -type d -name "antspriors*"`
gtmp=`find ${TemplateDir} -name "*template0.nii.gz"`
sessions=`find ${InDir}/${sub}/ -type d -name "ses-*" | cut -d "/" -f 5`

### Prep priors for T1w image
#priors=`find ${TemplateDir} -name "*Template_averageMask.nii.gz"`
#/scripts/prep.py --g ${gtmp} --s ${sst} --p ${priors}

### If the composite warp doesn't already exist, compute warp from group template to SST and the composite warp
### else, copy the composite warp into the output directory

# TODO: fix bug where inverse warp isn't set for subs in GT
for ses in ${sessions}; do

  compwarp="${TemplateDir}/SST/${sub}_${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz"
  
  # If subject was part of group template, composite warp will already exist.
  if [ -f ${compwarp} ]; then
    SST_to_GT_warp=`find ${TemplateDir}/ -name "${projectName}Template_${sub}_template*Warp.nii.gz" -not -name "*Inverse*"`
    SST_to_GT_affine=`find ${TemplateDir}/ -name "${projectName}Template_${sub}_template*Affine.mat" -not -name "*Inverse*"`
    cp ${SST_to_GT_warp} ${OutDir}/${sub}_Normalizedto${projectName}Template_Warp.nii.gz;
    cp ${SST_to_GT_affine} ${OutDir}/${sub}_Normalizedto${projectName}Template_Affine.mat;
    cp ${compwarp} ${OutDir};
  
  # Else, create composite warp
  else
    # Register SST to GT
    antsRegistrationSyN.sh -d 3 -f ${TemplateDir}/${projectName}Template_template0.nii.gz \
      -m ${InDir}/${sub}/${sub}_template0.nii.gz \
      -o ${OutDir}/${sub}_Normalizedto${projectName}Template_
    
    SST_to_GT_warp=`find ${OutDir}/ -name "${sub}_Normalizedto${projectName}Template_*Warp.nii.gz" -not -name "*Inverse*"`
    SST_to_GT_affine=`find ${OutDir}/ -name "${sub}_Normalizedto${projectName}Template_*Affine.mat" -not -name "*Inverse*"`
    
    # Calculate composite warp
    Native_to_SST_warp=`find ${InDir}/${sub}/${ses}/ -name "*padscale*Warp.nii.gz" -not -name "*Inverse*"`;
    Native_to_SST_affine=`find ${InDir}/ -name "${sub}_${ses}_desc-preproc_T1w_padscale*Affine.txt"`;
    
    # Composite t1w space to group template space
    antsApplyTransforms \
      -d 3 \
      -e 0 \
      -o [${OutDir}/${sub}_${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz, 1] \
      -r ${TemplateDir}/${projectName}Template_template0.nii.gz \
      -t ${SST_to_GT_warp} \
      -t ${SST_to_GT_affine} \
      -t ${Native_to_SST_warp} \
      -t ${Native_to_SST_affine};
  fi;
done

###############################################################################
########## Step 1. Warp priors in group template space to SST space ###########
###############################################################################

### Warp priors in group template space to SST space #antsApplyTransforms not working/NECESSARY??
priors=`find ${TemplateDir} -name "*Template_prior.nii.gz"`

GT_to_SST_warp=`find ${OutDir} -name "${sub}_Normalizedto${projectName}Template_*InverseWarp.nii.gz"`

for prior in ${priors}; do
  tissue=`echo ${prior} | cut -d "/" -f 6 | cut -d "_" -f 1`;
  antsApplyTransforms \
    -d 3 -e 0 -i ${prior} \
    -n Gaussian \
    -o [${OutDir}/${tissue}Prior_Normalizedto_${sub}_template.nii.gz,0] \
    -r ${sst} \
    -t [${SST_to_GT_affine},1] \
    -t ${GT_to_SST_warp}
done

###############################################################################
########### Step 2. Atropos on SST, using custom tissue priors.
###############################################################################

### Create a mask out of all non-zero voxels of warped priors
python /scripts/maskPriorsWarpedToSST.py ${sub}
groupMaskInSST=`find ${OutDir} -name "${sub}_priorsMask.nii.gz"`

## TODO: try making mask by running brain extraction on warped group priors instead of above.

### Copy priors to simpler name
cp ${OutDir}/BrainstemPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior1.nii.gz
cp ${OutDir}/CSFPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior2.nii.gz
cp ${OutDir}/CerebellumPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior3.nii.gz
cp ${OutDir}/GMCorticalPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior4.nii.gz
cp ${OutDir}/GMDeepPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior5.nii.gz
cp ${OutDir}/WMCorticalPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior6.nii.gz

### Perform Atropos on SST, using custom priors (weight = .25)
antsAtroposN4.sh -d 3 -a ${sst} -x ${groupMaskInSST} -c 6 -o ${OutDir}/${sub}_ \
  -w .25 -p ${OutDir}/prior%d.nii.gz

### Delete priors with simpler name
rm ${OutDir}/prior*.nii.gz

###############################################################################
## Step 3. Warp segmentation posterior to T1w Space. Run Atropos on T1w image (session).
###############################################################################

### Warp posteriors in SST space to T1w (ses) space
posteriors=`find ${OutDir} -name "${sub}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`
for ses in ${sessions}; do
  mkdir ${OutDir}/${ses}
  SST_to_Native_warp=`find ${InDir}/${sub}/${ses}/ -name "*InverseWarp.nii.gz"`
  Native_to_SST_affine=`find ${InDir}/${sub}/${ses}/ -name "*_desc-preproc_T1w_padscale*Affine.txt"`
  for post in ${posteriors}; do
    warpedname=`echo ${post} | cut -d "/" -f 4 | cut -d "_" -f 2 | cut -d "." -f 1`
    warpedname=${warpedname}_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz
    antsApplyTransforms \
      -d 3 -e 0 -i ${post} \
      -n Gaussian \
      -o [${OutDir}/${ses}/${warpedname},0] \
      -r ${InDir}/${sub}/${ses}/${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz \
      -t [${Native_to_SST_affine},1] \
      -t ${SST_to_Native_warp}
      # ^ Order of transforms switched April 6, 2021
  done
  
  ### Use output of Atropos on the SST as priors Atropos on sessions (weight = .5)
  ### Get cortical thickness (feed in hard segmentation for Atropos on session)
  python /scripts/maskPriorsWarpedToSes.py ${sub} ${ses}
  groupMaskInSes=${OutDir}/${ses}/${sub}_${ses}_priorsMask.nii.gz

  ### Copy posteriors to simpler name
  cp ${OutDir}/${ses}/SegmentationPosteriors1_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior1.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors2_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior2.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors3_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior3.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors4_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior4.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors5_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior5.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors6_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior6.nii.gz
  
  # Atropos on session
  antsAtroposN4.sh -d 3 -a ${InDir}/${sub}/${ses}/${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz \
    -x ${groupMaskInSes} -c 6 -o ${OutDir}/${ses}/${sub}_${ses}_ -w .5 \
    -p ${OutDir}/${ses}/prior%d.nii.gz
  
  # Delete priors with simpler name
  rm ${OutDir}/${ses}/prior*.nii.gz

###############################################################################
########### Step 4. Run cortical thickness. Use GM posterior as GMD image
###############################################################################

  t1w=${InDir}/${sub}/${ses}/${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz
  seg=${OutDir}/${ses}/${sub}_${ses}_Segmentation.nii.gz
  cp ${seg} ${OutDir}/${ses}/${sub}_${ses}_Segmentation_old.nii.gz
  sespost=`find ${OutDir}/${ses} -name "${sub}_${ses}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`;
  
  # Copy cortical gray matter posteriors to GMD image
  cp ${OutDir}/${ses}/${sub}_${ses}_SegmentationPosteriors4.nii.gz ${OutDir}/${ses}/${sub}_${ses}_GMD.nii.gz;
  
  # Run cortical thickness
  t1w=${InDir}/${sub}/${ses}/${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz;
  python /opt/bin/do_antsxnet_thickness.py -a ${t1w} -s ${seg} -p ${sespost} -o ${OutDir}/${ses}/${sub}_${ses}_ -t 1 ;

  ### Warp DKT labels from the group template space to the T1w space
  # Calculate the composite inverse warp
  SST_to_Native_warp=`find ${InDir}/${sub}/${ses}/ -name "*padscale*InverseWarp.nii.gz"`;
  Native_to_SST_affine=`find ${InDir}/ -name "${sub}_${ses}_desc-preproc_T1w_padscale*Affine.txt"`;
  GT_to_SST_warp=`find ${OutDir} -name "${sub}_NormalizedtoExtraLongTemplate_*InverseWarp.nii.gz"`;
  antsApplyTransforms \
    -d 3 \
    -e 0 \
    -o [${OutDir}/${ses}/${sub}_${ses}_Normalizedto${projectName}TemplateCompositeInverseWarp.nii.gz, 1] \
    -r ${TemplateDir}/${projectName}Template_template0.nii.gz \
    -t [${Native_to_SST_affine}, 1] \
    -t ${SST_to_Native_warp} \
    -t [${SST_to_GT_affine}, 1] \
    -t ${GT_to_SST_warp}
    # ^ Order of transforms switched April 6, 2021
  # Transform labels from group template to t1w space
  antsApplyTransforms \
    -d 3 -e 0 -n Multilabel \
    -i ${TemplateDir}/${projectName}Template_malfLabels.nii.gz \
    -o [${OutDir}/${ses}/${sub}_${ses}_DKT.nii.gz, 0] \
    -r ${t1w} \
    -t ${OutDir}/${ses}/${sub}_${ses}_Normalizedto${projectName}TemplateCompositeInverseWarp.nii.gz

  ### Quantify regional values
  ### Create a mask out of the cortical thickness image (try dividng by itself in ANTs - nope, puts in 1 for 0/0)
  #ImageMath 3 ${OutDir}/${ses}/${sub}_${ses}_CorticalThickness_mask.nii.gz TruncateImageIntensity ${OutDir}/${ses}/${sub}_${ses}_CorticalThickness.nii.gz binary-maskImage
  python /scripts/maskCT.py ${sub} ${ses} ${subLabel}
  
  ### Take the intersection of the cortical thickness mask and the DKT label
  ### image to get labels that conform to gray matter
  mask=${OutDir}/${ses}/${sub}_${ses}_CorticalThickness_mask.nii.gz
  imagename="${sub}_${ses}_DKTIntersection.nii.gz"
  ImageMath 3 ${OutDir}/${ses}/${imagename} m ${OutDir}/${ses}/${sub}_${ses}_DKT.nii.gz ${mask}
  ### Get cortical thickness, GMD and volume of each region
  #ImageMath 3 LabelStats ${OutDir}/${ses}/${sub}_${ses}_CorticalThickness.nii.gz ${OutDir}/${ses}/${sub}_${ses}_DKT.nii.gz

  python /scripts/quantifyROIs.py ${sub} ${ses} ${subLabel}
  # Move files to session directories
  mv ${OutDir}/*${ses}*.nii.gz ${OutDir}/${ses}
  #mv ${OutDir}/*${ses}*.txt ${OutDir}/${ses}
  
  # Remove unnecessary files (full output way too big)
  rm ${OutDir}/${ses}/*_CorticalThickness_mask.nii.gz
  rm ${OutDir}/${ses}/*_priorsMask.nii.gz
  rm ${OutDir}/${ses}/*Segmentation*
done

# Remove unnecessary files
rm ${OutDir}/*Prior*
rm ${OutDir}/*Segmentation*
rm ${OutDir}/*_Normalizedto${projectName}Template_*
rm ${OutDir}/*_priorsMask.nii.gz


### GMD: https://github.com/PennBBL/xcpEngine/blob/master/modules/gmd/gmd.mod
