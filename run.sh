export ANTSPATH=/opt/ants/bin/
export PATH=${ANTSPATH}:$PATH
export LD_LIBRARY_PATH=/opt/ants/lib

InDir=/data/input
OutDir=/data/output

# Bind
# 1.) Group template directory (template, priors and DKT labels needed)
# 2.) Single subect template directory directory (SST and padded/scaled T1w images needed)
# 3.) Output directory

TemplateDir=`find ${InDir} -type d -name "antspriors*"`
GT=`find ${TemplateDir} -name "*template0.nii.gz"`
SST=`find ${InDir}/sub* -name "*template0.nii.gz"`
sub=`echo ${SST} | cut -d "/" -f 5 | cut -d "_" -f 1`
sessions=`find ${InDir}/${sub}/ -type d -name "ses-*" | cut -d "/" -f 5`

###############################################################################
############## Step 1. Get Native-to-GT space composite warp.  ################
###############################################################################

for ses in ${sessions}; do
  
  # Path if composite warp already exists. 
  composite_warp="${TemplateDir}/SST/${sub}_${ses}_Normalizedto${projectName}TemplateCompositeWarp.nii.gz"
  
  # If subject was part of group template, Native-to-GT composite warp will already exist.
  if [ -f ${composite_warp} ]; then
    
    SST_to_GT_warp=`find ${TemplateDir}/ -name "${projectName}Template_${sub}_template*Warp.nii.gz" -not -name "*Inverse*"`
    SST_to_GT_affine=`find ${TemplateDir}/ -name "${projectName}Template_${sub}_template*Affine.mat" -not -name "*Inverse*"`
    GT_to_SST_warp=`find ${TemplateDir} -name "${projectName}Template_${sub}_template*InverseWarp.nii.gz"`
    
    # Copy composite warp and SST-to-GT transforms into output dir.
    cp ${composite_warp} ${OutDir};
    cp ${SST_to_GT_warp} ${OutDir}/${sub}_Normalizedto${projectName}Template_Warp.nii.gz;
    cp ${SST_to_GT_affine} ${OutDir}/${sub}_Normalizedto${projectName}Template_Affine.mat;
    cp ${GT_to_SST_warp} ${OutDir}/${sub}_Normalizedto${projectName}Template_InverseWarp.nii.gz;
  
  # Else, the subject wasn't part of the group template, so the composite won't exist yet.
  # Register SST to GT then use antsApplyTransforms to create composite warp.
  else
    
    # Register SST to GT. Fixed: GT, Moving: SST.
    antsRegistrationSyN.sh -d 3 -f ${TemplateDir}/${projectName}Template_template0.nii.gz \
      -m ${InDir}/${sub}/${sub}_template0.nii.gz \
      -o ${OutDir}/${sub}_Normalizedto${projectName}Template_
    
    SST_to_GT_warp=`find ${OutDir}/ -name "${sub}_Normalizedto${projectName}Template_*Warp.nii.gz" -not -name "*Inverse*"`
    SST_to_GT_affine=`find ${OutDir}/ -name "${sub}_Normalizedto${projectName}Template_*Affine.mat" -not -name "*Inverse*"`
    Native_to_SST_warp=`find ${InDir}/${sub}/${ses}/ -name "*padscale*Warp.nii.gz" -not -name "*Inverse*"`;
    Native_to_SST_affine=`find ${InDir}/ -name "${sub}_${ses}_desc-preproc_T1w_padscale*Affine.txt"`;
    
    # Calculate composite warp from Native T1w space to Group Template space.
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
####### Step 2. Transform priors from Group Template space to SST space. ######
###############################################################################

# Tissue priors in GT space
priors=`find ${TemplateDir} -name "*Template_prior.nii.gz"`

# Find inverse warp to go from GT space to SST space.
GT_to_SST_warp=`find ${OutDir} -name "${sub}_Normalizedto${projectName}Template_*InverseWarp.nii.gz"`

# Transform priors from GT space to SST space.
for prior in ${priors}; do
  
  # Get tissue type
  tissue=`echo ${prior} | cut -d "/" -f 6 | cut -d "_" -f 1`;

  antsApplyTransforms \
    -d 3 -e 0 -i ${prior} \
    -n Gaussian \
    -o [${OutDir}/${tissue}Prior_Normalizedto_${sub}_template.nii.gz,0] \
    -r ${SST} \
    -t [${SST_to_GT_affine},1] \
    -t ${GT_to_SST_warp}
done

###############################################################################
####### Step 3. Atropos segmentation on SST, using custom tissue priors. ######
###############################################################################

# OLD: Create mask from any non-zero voxels in all six warped priors.
python /scripts/maskPriorsWarpedToSST.py ${sub}
groupMaskInSST=`find ${OutDir} -name "${sub}_priorsMask.nii.gz"`

## TODO!: try making mask by running brain extraction on warped group priors instead of above.
maskedSST="${InDir}/${sub}/${sub}_BrainExtractionMask.nii.gz"

# Copy priors to simpler name for easy submission to Atropos script.
cp ${OutDir}/BrainstemPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior1.nii.gz
cp ${OutDir}/CSFPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior2.nii.gz
cp ${OutDir}/CerebellumPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior3.nii.gz
cp ${OutDir}/GMCorticalPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior4.nii.gz
cp ${OutDir}/GMDeepPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior5.nii.gz
cp ${OutDir}/WMCorticalPrior_Normalizedto_${sub}_template.nii.gz ${OutDir}/prior6.nii.gz

# Run Atropos on SST, using custom priors (weight = .25)
antsAtroposN4.sh -d 3 -a ${SST} -x ${maskedSST} -c 6 -o ${OutDir}/${sub}_ \
  -w .25 -p ${OutDir}/prior%d.nii.gz

# Delete copied priors.
rm ${OutDir}/prior*.nii.gz

###############################################################################
########## Step 4. Warp segmentation posteriors (from first Atropos   #########
##########         run) from SST space to native T1w space.           #########
###############################################################################

# Get segmentation posteriors from first Atropos run.
posteriors=`find ${OutDir} -name "${sub}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`

# For each session:
#   1. Warp segmentation posteriors from SST to session space.
#   2. Run Atropos segmentation on native T1w image.
for ses in ${sessions}; do

  # Make session level output directory
  mkdir ${OutDir}/${ses}

  # Get SST-to-Native warp/affine
  SST_to_Native_warp=`find ${InDir}/${sub}/${ses}/ -name "*InverseWarp.nii.gz"`
  Native_to_SST_affine=`find ${InDir}/${sub}/${ses}/ -name "*_desc-preproc_T1w_padscale*Affine.txt"`
  
  # Warp each tissue posterior from SST space to native T1w space.
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
  done
  
  # OLD
  python /scripts/maskPriorsWarpedToSes.py ${sub} ${ses}
  groupMaskInSes=${OutDir}/${ses}/${sub}_${ses}_priorsMask.nii.gz

  # TODO: Try using (dialated!) native T1w brain mask for priors mask instead of above.
  maskedT1w="${InDir}/fmriprep/ses-PNC1/anat/${sub}_${ses}_desc-brain_mask.nii.gz"
  # Pad
  ImageMath 3 ${InDir}/fmriprep/ses-PNC1/anat/${sub}_${ses}_desc-brain_mask_padded.nii.gz PadImage ${maskedT1w} 25

  # Copy warped posteriors to simpler name for easy submission to Atropos script.
  cp ${OutDir}/${ses}/SegmentationPosteriors1_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior1.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors2_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior2.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors3_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior3.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors4_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior4.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors5_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior5.nii.gz
  cp ${OutDir}/${ses}/SegmentationPosteriors6_Normalizedto_${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz ${OutDir}/${ses}/prior6.nii.gz
  
  T1w=${InDir}/${sub}/${ses}/${sub}_${ses}_desc-preproc_T1w_padscale.nii.gz
  
  # Atropos segmentation on native T1w image. Uses posteriors from Atropos on SST
  # as priors for Atropos on the native T1w image (weight = .5).
  antsAtroposN4.sh -d 3 -a ${T1w} \
    -x ${maskedT1w} -c 6 -o ${OutDir}/${ses}/${sub}_${ses}_ -w .5 \
    -p ${OutDir}/${ses}/prior%d.nii.gz
  
  # Delete copied priors.
  rm ${OutDir}/${ses}/prior*.nii.gz

###############################################################################
#####  Step 5. Get cortical thickness. Use CorticalGM posterior for GMD.  #####
###############################################################################
  
  # OLD: Use cortical gray matter posterior as GMD image.
  gmd="${OutDir}/${ses}/${sub}_${ses}_GMD.nii.gz"
  cp ${OutDir}/${ses}/${sub}_${ses}_SegmentationPosteriors4.nii.gz ${gmd}

  # Run cortical thickness script
  segmentation=${OutDir}/${ses}/${sub}_${ses}_Segmentation.nii.gz
  cp ${segmentation} ${OutDir}/${ses}/${sub}_${ses}_Segmentation_old.nii.gz
  posteriors=`find ${OutDir}/${ses} -name "${sub}_${ses}_SegmentationPosteriors*.nii.gz" -not -name "*PreviousIteration*"`;
  python /opt/bin/do_antsxnet_thickness.py -a ${T1w} -s ${segmentation} -p ${posteriors} -o ${OutDir}/${ses}/${sub}_${ses}_ -t 1 ;

###############################################################################
######  Step 6. Warp DKT labels from GT space to native T1w space.   ######
###############################################################################

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

  # Transform labels from group template to t1w space
  antsApplyTransforms \
    -d 3 -e 0 -n Multilabel \
    -i ${TemplateDir}/${projectName}Template_malfLabels.nii.gz \
    -o [${OutDir}/${ses}/${sub}_${ses}_DKT.nii.gz, 0] \
    -r ${t1w} \
    -t ${OutDir}/${ses}/${sub}_${ses}_Normalizedto${projectName}TemplateCompositeInverseWarp.nii.gz

###############################################################################
######  Step 7. Quantify regional values.                                ######
###############################################################################

  ### Quantify regional values
  # Get mask from the cortical thickness image.
  #ImageMath 3 ${OutDir}/${ses}/${sub}_${ses}_CorticalThickness_mask.nii.gz TruncateImageIntensity ${OutDir}/${ses}/${sub}_${ses}_CorticalThickness.nii.gz binary-maskImage
  python /scripts/maskCT.py ${sub} ${ses} ${subLabel}
  
  # Take intersection of CT mask and the DKT label image to get labels that conform to gray matter.
  ct="${OutDir}/${ses}/${sub}_${ses}_CorticalThickness.nii.gz"
  mask="${OutDir}/${ses}/${sub}_${ses}_CorticalThickness_mask.nii.gz"
  dkt="${OutDir}/${ses}/${sub}_${ses}_DKT.nii.gz"
  intersection="${OutDir}/${ses}/${sub}_${ses}_DKTIntersection_long.nii.gz"
  ImageMath 3 ${intersection} m ${dkt} ${mask}
  
  #ImageMath 3 LabelStats ${OutDir}/${ses}/${sub}_${ses}_CorticalThickness.nii.gz ${OutDir}/${ses}/${sub}_${ses}_DKT.nii.gz
  python /scripts/quantifyROIs.py ${intersection} ${ct} ${gmd}

###############################################################################
######  Step 8. Clean up.                                                ######
###############################################################################

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
