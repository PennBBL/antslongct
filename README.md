# ANTsLongCT

ANTsLongCT utilizes the output of [ANTsSST](https://github.com/PennBBL/antssst)
and [ANTsPriors](https://github.com/PennBBL/antspriors) to get volume, cortical
thickness and gray matter density values for every region in the DKT atlas. Cortical
thickness is computed using ANTs' cortical thickness algorithm.


## Docker
### Setting up
You must [install Docker](https://docs.docker.com/get-docker/) to use the ANTsLongCT
Docker image.

After Docker is installed, pull the ANTsLongCT image by running the following command:
`docker pull pennbbl/antslongct:0.0.10`.

Typically, Docker is used on local machines and not clusters because it requires
root access. If you want to run the container on a cluster, follow the Singularity
instructions.

### Running ANTsLongCT
Here is an example from one of Ellyn's runs:
```
docker run --rm -ti  -e projectName="ExtraLong" -e subLabel="bblid" \
  -v /Users/butellyn/Documents/ExtraLong/data/singleSubjectTemplates/antssst5/sub-10410:/data/input/sub-10410 \
  -v /Users/butellyn/Documents/ExtraLong/data/groupTemplates/antspriors:/data/input/antspriors \
  -v /Users/butellyn/Documents/ExtraLong/data/corticalThickness/antslongct3/sub-10410:/data/output \
  pennbbl/antslongct:0.0.10
```

- Line 1: Specify environment variables: the name of the project without any spaces
(`projectName`), and what you want the subject label column to be called (`subLabel`).
- Line 2: Bind a subject's ANTsSST output directory
(`/Users/butellyn/Documents/ExtraLong/data/singleSubjectTemplates/antssst5/sub-100079`)
to the subject's ANTsSST directory in the container (`/data/input/antssst/sub-100079`).
Note that the `antssst` directory outside of the container must start with the string
`antssst`, but after that can contain any other characters. Ellyn has it as `antssst5`
because she got good output on her fifth try.
- Line 3: Bind the group template directory (`/Users/butellyn/Documents/ExtraLong/data/groupTemplates/antspriors`)
to its spot in the container (`/data/input/antspriors`).
- Line 4: Bind the directory where you want your ANTsLongCT output to end up
(`/Users/butellyn/Documents/ExtraLong/data/corticalThickness/antslongct3/sub-10410`)
to the output directory in the container (`/data/output`).
- Line 5: Specify the Docker image and version. Run `docker images` to see if you
have the correct version pulled.

Substitute your own values for the files/directories to bind.

## Singularity
### Setting up
You must [install Singularity](https://singularity.lbl.gov/docs-installation) to
use the ANTsLongCT Singularity image.

After Singularity is installed, pull the ANTsLongCT image by running the following command:
`singularity pull docker://pennbbl/antslongct:0.0.10`.

Note that Singularity does not work on Macs, and will almost surely have to be
installed by a system administrator on your institution's computing cluster.

### Running ANTsLongCT
Here is an example from one of Ellyn's runs:
```
SINGULARITYENV_projectName=ExtraLong SINGULARITYENV_subLabel=bblid singularity run --writable-tmpfs --cleanenv \
  -B /project/ExtraLong/data/singleSubjectTemplates/antssst5/sub-10410:/data/input/sub-10410 \
  -B /project/ExtraLong/data/groupTemplates/antspriors:/data/input/antspriors/ \
  -B /project/ExtraLong/data/corticalThickness/antslongct3/sub-10410:/data/output \
  /project/ExtraLong/images/antslongct_0.0.10.sif
```

- Line 1: Specify environment variables: the name of the project without any spaces
(`projectName`), and what you want the subject label column to be called (`subLabel`).
- Line 2: Bind a subject's ANTsSST output directory
(`/project/ExtraLong/data/singleSubjectTemplates/antssst5/sub-10410`)
to the subject's ANTsSST directory in the container (`/data/input/antssst/sub-100079`).
Note that the `antssst` directory outside of the container must start with the string
`antssst`, but after that can contain any other characters. Ellyn has it as `antssst5`
because she got good output on her fifth try.
- Line 3: Bind the group template directory (`/project/ExtraLong/data/groupTemplates/antspriors`)
to its spot in the container (`/data/input/antspriors`).
- Line 4: Bind the directory where you want your ANTsLongCT output to end up
(`/project/ExtraLong/data/corticalThickness/antslongct3/sub-10410`)
to the output directory in the container (`/data/output`).
- Line 5: Specify the Singularity image file.

Substitute your own values for the files/directories to bind.

## Example Scripts
See [this script](https://github.com/PennBBL/ExtraLong/blob/master/scripts/process/ANTsLong/submitANTsLongCT_v0.0.10.py)
for an example of building a launch script per subject.

## Notes
1. For details on how ANTsLongCT was utilized for the ExtraLong project (all
longitudinal T1w data in the BBL), see [this wiki](https://github.com/PennBBL/ExtraLong/wiki).

## Future Directions
1. Set home directory in Dockerfile.
2. Get volumes of subcortical labels (will require tinkering with [ANTsPriors](https://github.com/PennBBL/antspriors)).
3. Evaluate whether method of computing GMD is comparable to [Stathis' method](https://github.com/egenn/JNeurosci_GMDVdev_2017).
4. Improve overlap between cortical thickness image and DKT labels.
5. Fix ANTs seed.
