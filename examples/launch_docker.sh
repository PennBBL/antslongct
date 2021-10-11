#!/bin/bash

# Run docker container interactively
docker run -it --rm --entrypoint=/bin/bash \
  -v /Users/kzoner/BBL/projects/ANTS/data/ANTsLongitudinal/0.1.0/:/data/output \
  katjz/antslongct:0.1.0 -i

# Run docker container (non-interactively)
docker run -it --rm \
  -v /Users/kzoner/BBL/projects/ANTS/data/ANTsLongitudinal/0.1.0/:/data/output \
  katjz/antslongct:0.1.0 --project ExtraLong --seed 1 sub-93811
