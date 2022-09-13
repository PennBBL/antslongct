############################
# Get ANTs from DockerHub
# February 18, 2021: DON'T HAVE ACCESS TO BINARIES
FROM pennbbl/ants:0.0.1 as antsbinaries
ENV ANTs_VERSION 0.0.1

# Pick a specific version, once they starting versioning
#FROM cookpa/antspynet:latest

############################
# Install ANTsPyNet
FROM python:3.8.12-buster as builder

COPY requirements.txt /opt

# ANTsPy just used to get the data directory from its source zip
ARG ANTSPY_DATA_VERSION=0.3.2

ENV VIRTUAL_ENV=/opt/venv

RUN apt-get update && \
    python3 -m venv ${VIRTUAL_ENV} && \
    . ${VIRTUAL_ENV}/bin/activate && \
    pip install wheel && \
    pip install nilearn && \
    pip install --requirement /opt/requirements.txt && \
    pip install antspynet==0.1.8 && \
    wget -O /opt/antsPy-${ANTSPY_DATA_VERSION}.zip \
      https://github.com/ANTsX/ANTsPy/archive/refs/tags/v${ANTSPY_DATA_VERSION}.zip && \
    unzip /opt/antsPy-${ANTSPY_DATA_VERSION}.zip -d /opt/ANTsPy && \
    cp -r /opt/ANTsPy/ANTsPy-${ANTSPY_DATA_VERSION}/data /opt/antspydata

FROM python:3.8.12-slim-buster

RUN apt-get update && apt-get install -y bc

COPY --from=builder /opt/venv /opt/venv
COPY --from=antsbinaries /opt/ants /opt/ants

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1

# Switch back to root from antspyuser in base layer
USER root

ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN mkdir /opt/dataCache /opt/bin

# Copy script
COPY do_antsxnet_thickness.py /opt/bin
COPY get_DKT_labels.py /opt/bin

# Copy data required by the cortical thickness pipeline
COPY ANTsXNetData /opt/dataCache/ANTsXNet

# Overwrite DKT labelling script so that it works with pre-downloaded data
COPY desikan_killiany_tourville_labeling.py /opt/venv/lib/python3.8/site-packages/antspynet/utilities/desikan_killiany_tourville_labeling.py

LABEL maintainer="Philip A Cook (https://github.com/cookpa)" \
      description="Cortical thickness script by Nick Tustison. \
                   ANTsPyNet is part of the ANTsX ecosystem (https://github.com/ANTsX). \
                   Citation: https://www.medrxiv.org/content/10.1101/2020.10.19.20215392v1"

# Install CUDA version 10.1
#RUN sudo dnf install cuda-toolkit-10-1 \
#    nvidia-driver-cuda akmod-nvidia

############################
RUN mkdir /data
RUN mkdir /data/input
RUN mkdir /data/output
RUN mkdir /data/input/atlases

RUN mkdir /scripts

COPY OASIS_PAC /data/input/OASIS_PAC
COPY mindboggleCorticalLabels.csv /data/input/atlases/mindboggleCorticalLabels.csv

COPY run.sh /scripts/run.sh
COPY maskPriorsWarpedToSST.py /scripts/maskPriorsWarpedToSST.py
COPY maskPriorsWarpedToSes.py /scripts/maskPriorsWarpedToSes.py
COPY quantifyROIs.py /scripts/quantifyROIs.py
COPY maskCT.py /scripts/maskCT.py

RUN chmod +x /scripts/*

#COPY mindboggle /scripts/mindboggle
 
# Set the entrypoint using exec format
ENTRYPOINT ["/scripts/run.sh"]
