#!/bin/bash

# Run docker container interactively
docker run -it --rm --entrypoint=/bin/bash \
  -e projectName="ExtraLong" -e subLabel="bblid" \
  -v /Users/kzoner/BBL/projects/ANTS/test_data/singleSubjectTemplates/sub-93811/:/data/input/sub-93811 \
  -v /Users/kzoner/BBL/projects/ANTS/test_data/groupTemplates/sub-93811:/data/input/antspriors \
  -v /Users/kzoner/BBL/projects/ANTS/test_data/corticalThickness/sub-93811:/data/output \
  pennbbl/antslongct -i
