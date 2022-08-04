#!/bin/bash

# ANTsLongCT: Cortical Thickness, GMD, and Volume calculations by DKT region.
# Maintainer: Katja Zoner
# Updated:    10/04/2021

VERSION=0.1.0

###############################################################################
##########################      Usage Function      ###########################
###############################################################################
usage() {
    cat <<-HELP_MESSAGE
		      usage:  $0 [--help] [--version] 
		                 [--jlf-on-gt | --jlf-on-sst ]
		                 [--project  <PROJECT NAME>]
		                 [--seed <RANDOM SEED>] 
		                 [--manual-step <STEP NUM>]
                         [--cleanup]
		                 SUB
		      
		      positional arguments:
		        SUB |                 Subject label
		      optional arguments:
		      -h  | --help            Print this message and exit.
		      -g  | --jlf-on-gt       Set if JLF was run on GT. (Default: False)
		      -j  | --jlf-on-sst      Set if JLF was run on SST. (Default: False)
		      -m  | --manual-step     Manually identify which steps to run. 
		                                1: construct composite warp, 
		                                2: run Atropos on SST, 
		                                3: run Atropos on native T1w,
		                                4: warp labels to native T1w space,
		                                5: quantify cortical thickness, GMD, volume in ROIs.
		                              Use multiple times to select multiple steps. (e.g. -m 2 -m 3)
		      -p  | --project         Project name for group template naming. (Default: "Group")
		      -s  | --seed            Random seed for ANTs registration.
              -x  | --cleanup         Delete unnecessary output files when finished.
		      -v  | --version         Print version and exit.
	HELP_MESSAGE
}

###############################################################################
###############      Error Handling and Cleanup Functions      ################
###############################################################################
clean_exit() {
    err=$?
    if [ $err -eq 0 ]; then
        echo "$0: ANTsLongCT finished successfully!"
        cleanup
    else
        echo "$0: ${PROGNAME:-}: ${1:-"Exiting with error code $err"}" 1>&2
    fi
    exit $err
}

cleanup() {
    echo -e "\nRunning cleanup ..."
    rm -rf $tmpdir
    echo "Done."
}

control_c() {
    echo -en "\n\n*** User pressed CTRL + C ***\n\n"
}

# Write progress message ($1) to both stdout and stderrs
log_progress() {
    echo -e "\n************************************************************" | tee -a /dev/stderr
    echo -e "***************     $1" | tee -a /dev/stderr
    echo -e "************************************************************\n" | tee -a /dev/stderr
}

# Helper function for cleanup to delete only if file exists.
delete_if_exists(){
    f=$1
    if [ -e $f ]; then
        rm -rf $f
    fi
}
###############################################################################
##############    1. Get Native-to-GT space composite warp.    ################
###############################################################################
construct_composite_warps() {
    log_progress "BEGIN: Constructing native-to-group template composite warps. \n"
    PROGNAME="construct_composite_warp()"
    
    # Get group template and single-subject template for use in later steps.
    GT=$(find ${OutDir} -maxdepth 1 -name "*template0.nii.gz")
    SST=$(find ${SubDir} -maxdepth 1 -name "*template0.nii.gz")

    for ses in ${sessions}; do
        SesDir="${SubDir}/sessions/${ses}"

        # Register SST to GT. Fixed: GT, Moving: SST.
        antsRegistrationSyN.sh \
            -d 3 \
            -f ${GT} \
            -m ${SST} \
            -o ${SubDir}/${sub}_to${projectName}Template_

        # Get warps and affines from Native to SST to GT space.
        #? : hard-coding 0/1 naming convention ok? --> Seems fine.
        SST_to_GT_warp=$(find ${SubDir} -name "${sub}_to*Template_1Warp.nii.gz")
        SST_to_GT_affine=$(find ${SubDir} -name "${sub}_to*Template_0GenericAffine.mat")
        Native_to_SST_warp=$(find ${SesDir} -name "${sub}_${ses}_toSST_Warp.nii.gz")
        Native_to_SST_affine=$(find ${SesDir} -name "${sub}_${ses}_toSST_Affine.txt")

        composite_warp=${SesDir}/${sub}_${ses}_to${projectName}Template_CompositeWarp.nii.gz

        # Calculate composite warp from Native T1w space to Group Template space.
        antsApplyTransforms \
            -d 3 \
            -e 0 \
            -o [${composite_warp}, 1] \
            -r ${GT} \
            -t ${SST_to_GT_warp} \
            -t ${SST_to_GT_affine} \
            -t ${Native_to_SST_warp} \
            -t ${Native_to_SST_affine}
    done

    log_progress "END: Finished constructing native-to-group template composite warps."
}

###############################################################################
#######  2.1) Transform priors from Group Template space to SST space.   ######
###############################################################################
transform_priors_to_sst() {
    log_progress "BEGIN: Transforming priors from GT to SST space."
    PROGNAME="transform_priors_to_sst()"

    # Tissue priors in GT space
    priors=$(find ${OutDir}/priors -name "*prior.nii.gz")

    # Get SST to use as reference image.
    SST=$(find ${SubDir} -maxdepth 1 -name "*template0.nii.gz")

    # Get inverse warp and affine to go from GT space to SST space.
    SST_to_GT_affine=$(find ${SubDir} -name "${sub}_to*Template_0GenericAffine.mat")
    GT_to_SST_warp=$(find ${SubDir} -name "${sub}_to*Template_*InverseWarp.nii.gz")

    # Make subdir for transformed priors in subject dir.
    PriorsDir="${SubDir}/priors"
    mkdir -p ${PriorsDir}

    # Transform each prior from GT space to SST space.
    for prior in ${priors}; do

        # Get tissue type
        tissue=$(basename ${prior} | cut -d "_" -f 2 | cut -d "-" -f 1)

        antsApplyTransforms \
            -d 3 \
            -e 0 \
            -i ${prior} \
            -n Gaussian \
            -o [${PriorsDir}/${tissue}Prior_WarpedTo_${sub}_template.nii.gz, 0] \
            -r ${SST} \
            -t [${SST_to_GT_affine},1]\
            -t ${GT_to_SST_warp} 
    done

    log_progress "END: Finished transforming priors from GT to SST space."
}

###############################################################################
#######  2.2) Atropos segmentation on SST, using custom tissue priors.   ######
###############################################################################
atropos_on_sst() {
    log_progress "BEGIN: Running Atropos segmentation on the SST."
    PROGNAME="atropos_on_sst()"

    # OLD: Create mask from any non-zero voxels in all six warped priors.
    # python /scripts/maskPriorsWarpedToSST.py ${sub}
    # groupMaskInSST=`find ${OutDir} -name "${sub}_priorsMask.nii.gz"`
    
    # Get SST to use as reference image.
    SST=$(find ${SubDir} -maxdepth 1 -name "*template0.nii.gz")
    # NEW! try making mask by running brain extraction on warped group priors instead of above.
    maskedSST="${SubDir}/${sub}_BrainExtractionMask.nii.gz"

    # Copy priors to simpler name for easy submission to Atropos script.
    cp ${SubDir}/priors/CSFPrior_WarpedTo_${sub}_template.nii.gz ${tmpdir}/prior1.nii.gz
    cp ${SubDir}/priors/GMCorticalPrior_WarpedTo_${sub}_template.nii.gz ${tmpdir}/prior2.nii.gz
    cp ${SubDir}/priors/WMCorticalPrior_WarpedTo_${sub}_template.nii.gz ${tmpdir}/prior3.nii.gz
    cp ${SubDir}/priors/GMDeepPrior_WarpedTo_${sub}_template.nii.gz ${tmpdir}/prior4.nii.gz
    cp ${SubDir}/priors/BrainstemPrior_WarpedTo_${sub}_template.nii.gz ${tmpdir}/prior5.nii.gz
    cp ${SubDir}/priors/CerebellumPrior_WarpedTo_${sub}_template.nii.gz ${tmpdir}/prior6.nii.gz

    # Run Atropos on SST, using custom priors (weight = .25)
    antsAtroposN4.sh \
        -d 3 \
        -c 6 \
        -w .25 \
        -a ${SST} \
        -x ${maskedSST} \
        -o ${SubDir}/${sub}_ \
        -p ${tmpdir}/prior%d.nii.gz

    # Delete copied priors.
    rm ${tmpdir}/prior*.nii.gz

    log_progress "END: Finished running Atropos segmentation on the SST."
}

###############################################################################
######      3.1) Warp segmentation posteriors (from first Atropos     #########
######         run) from SST space to native T1w space.               #########
###############################################################################
transform_posteriors_to_native() {
    log_progress "BEGIN: Transforming segmentation posteriors from SST to native space."
    PROGNAME="transform_posteriors_to_native()"

    # Get segmentation posteriors from first Atropos run.
    posteriors=$(find ${SubDir} -name "${sub}_SegmentationPosteriors*.nii.gz")

    # For each session, warp segmentation posteriors from SST to session space.
    for ses in ${sessions}; do
        SesDir="${SubDir}/sessions/${ses}"

        # Get Native T1w image
        t1w=$(find ${SesDir} -name ${sub}_${ses}_T1w.nii.gz)
        
        # Get SST-to-Native warp/affine
        SST_to_Native_warp=$(find ${SesDir} -name "${sub}_${ses}_toSST_InverseWarp.nii.gz")
        Native_to_SST_affine=$(find ${SesDir} -name "${sub}_${ses}_toSST_Affine.txt")
        

        for posterior in ${posteriors}; do
            name=$(basename ${posterior} | cut -d . -f 1)
            posterior_warped="${tmpdir}/${name}_WarpedToNative_${ses}.nii.gz"

            antsApplyTransforms \
                -d 3 \
                -e 0 \
                -n Gaussian \
                -i ${posterior} \
                -o [${posterior_warped}, 0] \
                -r ${t1w} \
                -t [${Native_to_SST_affine},1]\
                -t ${SST_to_Native_warp} 
        done

    done

    log_progress "END: Finished transforming segmentation posteriors from SST to native space."
}

###############################################################################
#######      3.2) Atropos segmentation on Native T1w img. Priors are    #######
#######        segmentation posteriors from first Atropos run.          #######
###############################################################################
atropos_on_native() {
    log_progress "BEGIN: Running Atropos segmentation on the native T1w image."
    PROGNAME="atropos_on_native()"

    for ses in ${sessions}; do
        SesDir="${SubDir}/sessions/${ses}"
        mkdir -p ${SesDir}/atropos

        # OLD:
        # python /scripts/maskPriorsWarpedToSes.py ${sub} ${ses}
        # groupMaskInSes=${OutDir}/${ses}/${sub}_${ses}_priorsMask.nii.gz

        # NEW:
        # Try using (dialated? padded?) native T1w brain mask for priors mask instead of above.
        # maskedT1w="${InDir}/fmriprep/${ses}/anat/${sub}_${ses}_desc-brain_mask.nii.gz"
        t1w_mask="${SesDir}/${sub}_${ses}_brain-mask.nii.gz"

        # Get Native T1w image
        t1w=$(find ${SesDir} -name ${sub}_${ses}_T1w.nii.gz)

        # Pad
        # ImageMath 3 ${InDir}/fmriprep/${ses}/anat/${sub}_${ses}_desc-brain_mask_padded.nii.gz PadImage ${maskedT1w} 25
        # TODO: try BE on t1w pad scale

        # Copy warped posteriors to simpler name for easy submission to Atropos script.
        cp ${tmpdir}/${sub}_SegmentationPosteriors1_WarpedToNative_${ses}.nii.gz ${tmpdir}/prior1.nii.gz
        cp ${tmpdir}/${sub}_SegmentationPosteriors2_WarpedToNative_${ses}.nii.gz ${tmpdir}/prior2.nii.gz
        cp ${tmpdir}/${sub}_SegmentationPosteriors3_WarpedToNative_${ses}.nii.gz ${tmpdir}/prior3.nii.gz
        cp ${tmpdir}/${sub}_SegmentationPosteriors4_WarpedToNative_${ses}.nii.gz ${tmpdir}/prior4.nii.gz
        cp ${tmpdir}/${sub}_SegmentationPosteriors5_WarpedToNative_${ses}.nii.gz ${tmpdir}/prior5.nii.gz
        cp ${tmpdir}/${sub}_SegmentationPosteriors6_WarpedToNative_${ses}.nii.gz ${tmpdir}/prior6.nii.gz

	    # Fix precision issue 
	    CopyImageHeaderInformation ${t1w} ${t1w_mask} ${t1w_mask} 0 1 0 	

        # Atropos segmentation on native T1w image. Uses posteriors from Atropos on SST
        # as priors for Atropos on the native T1w image (weight = .5).
        antsAtroposN4.sh \
            -d 3 \
            -c 6 \
            -w .5 \
            -a ${t1w} \
            -x ${t1w_mask} \
            -o ${SesDir}/atropos/${sub}_${ses}_ \
            -p ${tmpdir}/prior%d.nii.gz

        # Delete copied priors.
        rm ${tmpdir}/prior*.nii.gz

        prefix="${SesDir}/atropos/${sub}_${ses}"
        mv "${prefix}_SegmentationPosteriors1.nii.gz" "${prefix}_Segmentation-CSF.nii.gz" 
        mv "${prefix}_SegmentationPosteriors2.nii.gz" "${prefix}_Segmentation-GMCortical.nii.gz" 
        mv "${prefix}_SegmentationPosteriors3.nii.gz" "${prefix}_Segmentation-WMCortical.nii.gz" 
        mv "${prefix}_SegmentationPosteriors4.nii.gz" "${prefix}_Segmentation-GMDeep.nii.gz" 
        mv "${prefix}_SegmentationPosteriors5.nii.gz" "${prefix}_Segmentation-Brainstem.nii.gz"
        mv "${prefix}_SegmentationPosteriors6.nii.gz" "${prefix}_Segmentation-Cerebellum.nii.gz" 

    done
    
    log_progress "END: Finished running Atropos segmentation on the native T1w image."
}

###############################################################################
########    4. Warp DKT labels from GT space to native T1w space.      ########
###############################################################################
warp_gt_labels() {
    log_progress "BEGIN: Warping DKT labels from group template to native T1w space."
    PROGNAME="warp_gt_labels()"

    for ses in ${sessions}; do
        SesDir="${SubDir}/sessions/${ses}"

        # Get group template and single-subject template
        GT=$(find ${OutDir} -maxdepth 1 -name "*template0.nii.gz")
        SST=$(find ${SubDir} -maxdepth 1 -name "*template0.nii.gz")
        t1w=$(find ${SesDir} -name ${sub}_${ses}_T1w.nii.gz)

        # Get warps to build compositve inverse warp
        Native_to_SST_affine=$(find ${SesDir} -name "${sub}_${ses}_toSST_Affine.txt")
        SST_to_Native_warp=$(find ${SesDir} -name "${sub}_${ses}_toSST_*InverseWarp.nii.gz")
        SST_to_GT_affine=$(find ${SubDir} -name "${sub}_to*Template_0GenericAffine.mat")
        GT_to_SST_warp=$(find ${SubDir} -name "${sub}_to*Template_*InverseWarp.nii.gz")

        GT_to_Native_warp="${SesDir}/${sub}_${ses}_to${projectName}Template_CompositeInverseWarp.nii.gz"

        # Calculate the composite inverse warp from GT to native T1w space.
        # TODO: BUG (FIXED NOW): Reference img should be t1w, not GT! 
        antsApplyTransforms \
            -d 3 \
            -e 0 \
            -o [${GT_to_Native_warp}, 1] \
            -r ${t1w} \
            -t [${Native_to_SST_affine}, 1]\
            -t ${SST_to_Native_warp}  \
            -t [${SST_to_GT_affine}, 1] \
            -t ${GT_to_SST_warp} 

        # Get DKT-labeled GT image
        GT_labels="${OutDir}/${projectName}Template_DKT.nii.gz"
        Native_labels="${SesDir}/${sub}_${ses}_DKT.nii.gz"

        # Transform labels from group template to T1w space
        # NOTE: use -n 'Multilabel' interpolation for labeled image to maintain integer labels!
        antsApplyTransforms \
            -d 3 \
            -e 0 \
            -n Multilabel \
            -i ${GT_labels} \
            -o [${Native_labels}, 0] \
            -r ${t1w} \
            -t ${GT_to_Native_warp}

    done

    log_progress "END: Finished warping DKT labels to native T1w space."
}

warp_sst_labels() {

    log_progress "BEGIN: Warping DKT labels from subject template to native T1w space."
    PROGNAME="warp_sst_labels()"

    for ses in ${sessions}; do
        SesDir="${SubDir}/sessions/${ses}"

        # Get group template and single-subject template
        SST=$(find ${SubDir} -maxdepth 1 -name "*template0.nii.gz")
        t1w=$(find ${SesDir} -name ${sub}_${ses}_T1w.nii.gz)

        # Get SST-to-Native warp/affine
        Native_to_SST_affine=$(find ${SesDir} -name "${sub}_${ses}_toSST_Affine.txt")
        SST_to_Native_warp=$(find ${SesDir} -name "${sub}_${ses}_toSST_*InverseWarp.nii.gz")

        # Get DKT-labeled SST image
        SST_labels="${SubDir}/${sub}_DKT.nii.gz"
        Native_labels="${SesDir}/${sub}_${ses}_DKT.nii.gz"

        # Transform labels from group template to T1w space
        # NOTE: use -n 'Multilabel' interpolation for labeled image to maintain integer labels!
        antsApplyTransforms \
            -d 3 \
            -e 0 \
            -n Multilabel \
            -i ${SST_labels} \
            -o [${Native_labels}, 0] \
            -r ${t1w} \
            -t [${Native_to_SST_affine}, 1] \
            -t ${SST_to_Native_warp} 

    done

    log_progress "END: Finished warping DKT labels to native T1w space."
}

###############################################################################
######    5. Get cortical thickness and GMD. Quantify regional values.   ######                                   ######
###############################################################################
quantify() {
    log_progress "BEGIN: Calculating cortical thickness and GMD, and quantifying regional values."
    PROGNAME="quantify()"

    for ses in $sessions; do
        SesDir="${SubDir}/sessions/${ses}"

        # Copy posteriors name format required by do_antsxnet_thickness.py
        prefix="${SesDir}/atropos/${sub}_${ses}"
        cp  "${prefix}_Segmentation-Brainstem.nii.gz" "${tmpdir}/${sub}_${ses}_SegmentationPosteriors1.nii.gz"
        cp  "${prefix}_Segmentation-CSF.nii.gz" "${tmpdir}/${sub}_${ses}_SegmentationPosteriors2.nii.gz" 
        cp  "${prefix}_Segmentation-Cerebellum.nii.gz" "${tmpdir}/${sub}_${ses}_SegmentationPosteriors3.nii.gz"
        cp  "${prefix}_Segmentation-GMCortical.nii.gz" "${tmpdir}/${sub}_${ses}_SegmentationPosteriors4.nii.gz"
        cp  "${prefix}_Segmentation-GMDeep.nii.gz" "${tmpdir}/${sub}_${ses}_SegmentationPosteriors5.nii.gz"
        cp  "${prefix}_Segmentation-WMCortical.nii.gz" "${tmpdir}/${sub}_${ses}_SegmentationPosteriors6.nii.gz"
        
        # Calculate cortical thickness using the segmentation image via DiReCT.
        t1w=$(find ${SesDir} -name ${sub}_${ses}_T1w.nii.gz)
        segmentation="${SesDir}/atropos/${sub}_${ses}_Segmentation.nii.gz"
        posteriors=$(find ${tmpdir} -name "${sub}_${ses}_SegmentationPosteriors*.nii.gz")

        python /opt/bin/do_antsxnet_thickness.py \
            -a ${t1w} \
            -s ${segmentation} \
            -p ${posteriors} \
            -o ${SesDir}/${sub}_${ses}_ \
            -t 1

        # Take intersection of CT mask and the DKT label image to get labels that conform to gray matter voxels.
        ct="${SesDir}/${sub}_${ses}_CorticalThickness.nii.gz"
        mask="${SesDir}/${sub}_${ses}_CorticalThickness-mask.nii.gz"
        dkt="${SesDir}/${sub}_${ses}_DKT.nii.gz"
        intersection="${SesDir}/${sub}_${ses}_CT-DKT-Intersection.nii.gz"
       
        ThresholdImage 3 ${ct} ${mask} 0.001 Inf
        ImageMath 3 ${mask} GetLargestComponent ${mask}
        ImageMath 3 ${dkt} PropagateLabelsThroughMask ${mask} ${intersection} 10

        # Get GMD image.
        # TODO: Talk to Stathis r.e. GMD calculations
        # GMD: https://github.com/PennBBL/xcpEngine/blob/master/modules/gmd/gmd.mod
        # OLD: Use cortical gray matter posterior as GMD image.
        gmd="${SesDir}/${sub}_${ses}_GMD.nii.gz"
        cp ${SesDir}/atropos/${sub}_${ses}_Segmentation-GMCortical.nii.gz ${gmd}

        # Quantify ROIs in terms of volume, cortical thickeness, and gray matter density.
        #ImageMath 3 LabelStats ${OutDir}/${ses}/${sub}_${ses}_CorticalThickness.nii.gz ${OutDir}/${ses}/${sub}_${ses}_DKT.nii.gz
        python /scripts/quantifyROIs.py -d ${intersection} -c ${ct} -g ${gmd}

    done

    log_progress "END: Finished regional values for volume, cortical thickness, and gray matter density."
}

###############################################################################
##########################         MAIN: SETUP        #########################
###############################################################################

# Set default cmd line args
projectName=Group
seed=1
labelsOnGT=""
labelsOnSST=""
runAll=1            # Default to running all if -m option not used.
runCompWarps=""     # -m 1
runAtroposSST=""    # -m 2
runAtroposNative="" # -m 3
runWarpLabels=""    # -m 4
runQuantify=""      # -m 5
runCleanUp=""

# Parse cmd line options
PARAMS=""
while (("$#")); do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    -g | --jlf-on-gt)
        labelsOnGT=1
        shift
        ;;
    -j | --jlf-on-sst)
        labelsOnSST=1
        shift
        ;;
    -m | --manual-step)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
            step=$2
            if [[ "$step" == "1" ]]; then
                runAll=""
                runCompWarps=1
            elif [[ "$step" == "2" ]]; then
                runAll=""
                runAtroposSST=1
            elif [[ "$step" == "3" ]]; then
                runAll=""
                runAtroposNative=1
            elif [[ "$step" == "4" ]]; then
                runAll=""
                runWarpLabels=1
            elif [[ "$step" == "5" ]]; then
                runAll=""
                runQuantify=1
            else
                echo "Error: $step is not a valid value for the --manual-step flag."
                exit 1
            fi
            shift 2
        else
            echo "$0: Error: Argument for $1 is missing" >&2
            exit 1
        fi
        ;;
    -p | --project)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
            projectName=$2
            shift 2
        else
            echo "$0: Error: Argument for $1 is missing" >&2
            exit 1
        fi
        ;;
    -s | --seed)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
            seed=$2
            shift 2
        else
            echo "$0: Error: Argument for $1 is missing" >&2
            exit 1
        fi
        ;;
    -x | --cleanup)
        runCleanUp=1
        shift
        ;;
    -v | --version)
        echo $VERSION
        exit 0
        ;;
    -* | --*=) # unsupported flags
        echo "$0: Error: Unsupported flag $1" >&2
        exit 1
        ;;
    *) # parse positional arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
done

# Set positional arguments (subject list) in their proper place
eval set -- "$PARAMS"

# Get subject label passed in via cmd line.
sub="$@"

# Check that one subject was provided.
if [[ $(echo $sub | wc -w) -ne 1 ]]; then
    echo "Error: Please provide the label for subject to be processed."
    exit 1
fi

# Set env vars for ANTs
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1
export ANTS_RANDOM_SEED=$seed

# Set ANTs path
export ANTSPATH=/opt/ants/bin
export PATH=${ANTSPATH}:$PATH
export LD_LIBRARY_PATH=/opt/ants/lib

# Make tmp dir
tmpdir="/data/output/tmp/${sub}"
mkdir -p ${tmpdir}

# Set up error handling
set -euo pipefail
trap 'clean_exit' EXIT
trap 'control_c' SIGINT

###############################################################################
########################        MAIN: PROCESSING       ########################
###############################################################################
log_progress "ANTsLongCT v${VERSION}: STARTING UP"

# Set paths to input/output/subject directories
InDir=/data/input
OutDir=/data/output
SubDir=${OutDir}/subjects/${sub}

# Make sure subject directory exists
if [[ ! -d ${SubDir} ]]; then
    echo "Error: No directory could be found for subject ${sub}"
    exit 1
fi

# Get session list (e.g. ses-PNC1, ses-MOTIVE )
sessions=`find ${SubDir} -type d -name "ses-*" -exec basename {} \;`

# Run composite warp creation.
if [[ ${runCompWarps} ]] || [[ ${runAll} ]]; then
    construct_composite_warps
fi

# Run Atropos on SST
if [[ ${runAtroposSST} ]] || [[ ${runAll} ]]; then
    # First, transform tissue priors to SST space...
    transform_priors_to_sst
    # ... then, run Atropos on the SST using warped custom priors.
    atropos_on_sst
fi

# Run Atropos on Native T1w
if [[ ${runAtroposNative} ]] || [[ ${runAll} ]]; then
    # First, transform tissue posteriors from prev Atropos run to native space...
    transform_posteriors_to_native
    # ... then, run Atropos on the native T1w image using tissue posteriors as new priors.
    atropos_on_native
fi

# Warp labels to Native T1w space
if [[ ${runWarpLabels} ]] || [[ ${runAll} ]]; then
    if [[ ${labelsOnGT} ]]; then
        warp_gt_labels
    elif [[ ${labelsOnSST} ]]; then
        warp_sst_labels
    else
        "Error: Please indicate whether JLF was run on the Group Template or the Single Subject Template via the corresponding cmd line arg."
        exit 1
    fi
fi

# Quantify volume, cortical thickness, and GMD in ROIs
if [[ ${runQuantify} ]] || [[ ${runAll} ]]; then
    quantify
fi

# Clean up and remove unnecessary files
if [[ ${runCleanUp} ]]; then
    delete_if_exists "${OutDir}/priors"
    delete_if_exists "${SubDir}/*Segmentation*"
    delete_if_exists "${SubDir}/*WarpedTo${projectName}Template*"
    for ses in $sessions; do
        delete_if_exists "${SubDir}/sessions/${ses}/*Composite*"
        delete_if_exists "${SubDir}/sessions/${ses}/*WarpedToSST*"
    done
fi

log_progress "ANTsLongCT v${VERSION}: FINISHED SUCCESSFULLY"
