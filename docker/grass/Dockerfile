FROM ubuntu:20.04

LABEL authors="Ken Mankoff"
LABEL maintainer="kdm@geus.dk"

# system environment
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && apt-get install -y --no-install-recommends --no-install-suggests \
      bc \
      bsdmainutils \
      datamash \
      gdal-bin \
      grass \
      netcdf-bin \
      parallel \
      proj-bin \
      proj-data \
      zip \
  && apt-get autoremove -y \
  && apt-get clean -y \ 
  && rm -rf /var/lib/apt/lists/*

RUN echo LANG="en_US.UTF-8" > /etc/default/locale

ENV LANGUAGE en_US.UTF-8
ENV LANG C
ENV LC_ALL C
ENV LC_CTYPE C

ENV SHELL /bin/bash

# create a user
RUN useradd --create-home user && chmod a+rwx /home/user
ENV HOME /home/user
WORKDIR /home/user

RUN mkdir -p /data
ENV DATADIR /data

# switch the user
USER user

CMD ["/usr/bin/grass", "--version"]
