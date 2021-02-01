# ANTsPriors

This image takes in the output from the anatomical stream from fMRIPrep and the output of ANTsSST to create a group template from the single subject templates provided, as well as tissue-class priors using an average of the individual sessions' freesurfer segmentations (e.g., sub-SUBLABEL_ses-SESLABEL_desc-aseg_dseg.nii.gz).

* Note: As of October 2020, ANTsPriors has only been tested with the output of fMRIPrep v 20.0.5 and ANTsSST v 0.0.2.
# antslongct
