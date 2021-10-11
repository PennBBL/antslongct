#!/bin/bash

# Run singularity container interactively
singularity shell --cleanenv --writable-tmpfs --containall \
  -B ~/ants_pipelines/data/ANTsLongitudinal/0.1.0/:/data/output \
  ~/ants_pipelines/images/antslongct_0.1.0.sif

# Run singularity container.
singularity run --cleanenv --writable-tmpfs --containall \
  -B ~/ants_pipelines/data/ANTsLongitudinal/0.1.0/:/data/output \
  ~/ants_pipelines/images/antslongct_0.1.0.sif --seed 1 --project ExtraLong sub-93811
