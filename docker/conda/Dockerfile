FROM continuumio/miniconda3

RUN conda install \
  curl \
  cython \
  ipython \
  jupyter \
  matplotlib \
  numpy \
  pandas \
  pip \
  scipy \
  statsmodels \
  tabulate \
  xarray \
  && conda clean -a \
  && pip install --no-cache-dir \
  cfchecker \
  cfunits \
  grass-session \
  nc-time-axis \
  pyshp \
  semver \
  uncertainties \
  git+https://github.com/aussda/pyDataverse.git@3b040ff23b665ec2650bebcf4bd5478de6881af0

# create a user
RUN useradd --create-home user && chmod a+rwx /home/user
ENV HOME /home/user
WORKDIR /home/user

RUN mkdir -p /data
ENV DATADIR /data

# switch the user
USER user


# create a user
# RUN useradd -m -U user

# RUN chmod a+rwx /home/user
# ENV HOME /home/user
# RUN mkdir -p /data /work
# WORKDIR /work

# switch the user
# USER user

# RUN mkdir -p /data /work
# WORKDIR /work

# The code to run when container is started:
# ENTRYPOINT ["conda", "run", "-n", "ice_discharge", "python3"]

# For interactive shell
# RUN conda init bash
# RUN echo "conda activate ice_discharge" >> /root/.bashrc
