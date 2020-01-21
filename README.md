# bax2bam pipeline


## About

Converts an FOFN file of ".bax.h5" (PacBio RS II) files to BAM files (PacBio Sequel)


## Setup

First, change to a working directory where all output data will be saved. This can be a clean directory with nothing in
it.


### Set environment

Define a variable that gives the full path to the pbsv pipeline code, which is the directory that contains `Snakefile`
and this `README.md` file. The pipeline itself does not use the variable, but commands in this README will.

Example:
`PIPELINE_DIR=/net/eichler/vol26/7200/software/pipelines/bax2bam/201910`

This section assumes the pipeline Snakefile is not in the working directory, which is the recommended usage. That means the
current directory is where the output files will be saved, but the pipeline code is in
a different directory so that it does not need to be copied each time it is run. If the pipeline code is in the same
directory as the output files, you can set `PIPELINE_DIR` to '.' or you can ignore it completely and adjust the commands
below.

### Load prerequisites

A set of pacbio tools, including bax2bam, and a python environment installed must be available before
running the pipeline.

Pipeline was last tested with these Eichler lab modules:
```
module load pbconda/201910
module load miniconda/4.5.11
```

## Run

Once `PIPELINE_DIR` is set to point to the pipeline directory where `Snakefile` exists, the pipeline is ready to run.


### Run pipeline

The tool reads an existing FOFN of ".bax.h5" files, groups them into cells (3 BAX files per cell), and writes one BAM
per cell. Replace `/path/to/sample.fofn` with a path to the FOFN file in the command below:

`snakemake -s ${PIPELINE_DIR}/Snakefile --config fofn=/path/to/sample.fofn`

Remove temporary files and logs after the pipeline is done.

`rm -rf temp .snakemake log`


### Run distributed

To distribute jobs over the cluster, make sure DRMAA_LIBRARY_PATH is set in the environment (see below). Use the command
below. You may want to modify the number of concurrent jobs (-j).

`mkdir -p log; snakemake -s ${PIPELINE_DIR}/Snakefile -j 30 -k --jobname "{rulename}.{jobid}" --drmaa " -V -cwd -e ./log -o ./log -pe serial {cluster.cpu} -l mfree={cluster.mem} -l h_rt={cluster.rt} -w n -S /bin/bash" -w 60 -u ${PIPELINE_DIR}/cluster.eichler.json --config fofn=/path/to/sample.fofn`

If DRMAA_LIBRARY_PATH is not set in your environment, run this before distributing jobs:

`export DRMAA_LIBRARY_PATH=/opt/uge/lib/lx-amd64/libdrmaa.so.1.0`

Remove temporary files and logs after the pipeline is done.

`rm -rf temp .snakemake log`
