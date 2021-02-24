docker run --rm -ti --entrypoint=/bin/bash \
  -v /Users/butellyn/Documents/ExtraLong/data/singleSubjectTemplates/antssst5/sub-113054:/data/input/sub-113054 \
  -v /Users/butellyn/Documents/ExtraLong/data/groupTemplates/versionSeventeen:/data/input/versionSeventeen \
  -v /Users/butellyn/Documents/ExtraLong/data/corticalThickness/antslongct:/data/output \
  pennbbl/antslongct


singularity exec --writable-tmpfs --cleanenv \
  -B /project/ExtraLong/data/singleSubjectTemplates/antssst5/sub-100079:/data/input/sub-100079 \
  -B /project/ExtraLong/data/groupTemplates/versionSeventeen:/data/input/versionSeventeen \
  -B /project/ExtraLong/data/corticalThickness/antslongct/sub-100079:/data/output \
  /project/ExtraLong/images/antslongct_0.0.1.sif /scripts/run.sh
#singularity shell for interactive
