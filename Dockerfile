############################
# Get ANTs from DockerHub
# Pick a specific version, once they starting versioning
FROM cookpa/antspynet:latest
#ENV ANTs_VERSION 0.0.1

############################
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
RUN chmod +x /scripts/*

# Set the entrypoint
ENTRYPOINT /scripts/run.sh
