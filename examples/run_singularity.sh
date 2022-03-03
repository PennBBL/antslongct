#!/bin/bash

export LOGS_DIR=/home/kzoner/logs/ExtraLong_2021/ANTsLongCT-0.1.0
mkdir -p ${LOGS_DIR}

scripts="/project/ExtraLong/scripts/datafreeze-2021/process/ANTsLongitudinal"
jsDir=${scripts}/jobscripts/ANTsLongCT-0.1.0
mkdir -p ${jsDir}

data="/project/ExtraLong/data/datafreeze-2021"
antslong_dir=${data}/ANTsLongitudinal

include_csv=${data}/QC/sessions_for_inclusion.csv
subList=$(cat ${include_csv} | cut -d , -f 1 | uniq | tail -n +2)
echo "ANTsLongCT will be run on $(echo $subList | wc -w) subjects"

for subject in $subList; do

	subject=sub-${subject}
	echo SUBJECT: $subject

    jobscript=${jsDir}/${subject}.sh

	cat <<-JOBSCRIPT >${jobscript}
		#!/bin/bash

		singularity run --writable-tmpfs --cleanenv  \\
			-B ${antslong_dir}:/data/output \\
			/project/ExtraLong/images/antslongct_0.1.0.sif --seed 1 --project ExtraLong ${subject} -m 1 -m 2 -m 3

	JOBSCRIPT

	chmod +x ${jobscript}
	bsub -e $LOGS_DIR/${subject}.e -o $LOGS_DIR/${subject}.o ${jobscript}
	
done
