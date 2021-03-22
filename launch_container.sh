docker run --rm -ti --entrypoint=/bin/bash -e projectName="ExtraLong" -e subLabel="bblid" \
  -v /Users/butellyn/Documents/ExtraLong/data/singleSubjectTemplates/antssst5/sub-113054:/data/input/sub-113054 \
  -v /Users/butellyn/Documents/ExtraLong/data/groupTemplates/antspriors:/data/input/antspriors \
  -v /Users/butellyn/Documents/ExtraLong/data/corticalThickness/antslongct2/sub-113054:/data/output \
  pennbbl/antslongct
#sub-113054 will need to be created in the python script


SINGULARITYENV_projectName=ExtraLong singularity exec --writable-tmpfs --cleanenv \
  -B /project/ExtraLong/data/singleSubjectTemplates/antssst5/sub-100079:/data/input/sub-100079 \
  -B /project/ExtraLong/data/groupTemplates/versionSeventeen:/data/input/versionSeventeen \
  -B /project/ExtraLong/data/corticalThickness/antslongct/sub-100079:/data/output \
  /project/ExtraLong/images/antslongct_0.0.1.sif /scripts/run.sh
#singularity shell for interactive
