############################
# Get ANTs from DockerHub
# February 18, 2021: DON'T HAVE ACCESS TO BINARIES
FROM pennbbl/ants:0.0.1 as antsbinaries
ENV ANTs_VERSION 0.0.1

# Pick a specific version, once they starting versioning
#FROM cookpa/antspynet:latest

############################
# Install ANTsPyNet
FROM python:3.8.6-buster as builder

COPY requirements.txt /opt

RUN apt-get update && \
    apt-get install -y cmake=3.13.4-1 && \
    python3 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install wheel && \
    pip install --use-feature=2020-resolver --requirement /opt/requirements.txt && \
    pip install --use-feature=2020-resolver git+https://github.com/ANTsX/ANTsPyNet.git@5f64287e693ff15b3588233b13eb065307a846e2 && \
    git clone https://github.com/ANTsX/ANTsPy.git /opt/ANTsPy 

FROM python:3.8.6-slim

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

# Copy data required by the cortical thickness pipeline
COPY ANTsXNetData /opt/dataCache/ANTsXNet

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
RUN mkdir /scripts
COPY run.sh /scripts/run.sh
COPY maskPriorsWarpedToSST.py /scripts/maskPriorsWarpedToSST.py
COPY maskPriorsWarpedToSes.py /scripts/maskPriorsWarpedToSes.py
COPY maskCT.py /scripts/maskCT.py
RUN chmod +x /scripts/*

COPY mindboggle /scripts/mindboggle

COPY mindboggleCorticalLabels.csv /data/input/mindboggleCorticalLabels.csv

# Set the entrypoint
ENTRYPOINT /scripts/run.sh
