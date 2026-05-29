container_cmd ?= docker
container_args ?= run --user $(shell id -u):$(shell id -g) --mount type=bind,src=$${DATADIR},dst=/data --mount type=bind,src=$(shell pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1"

SHELL = bash
.DEFAULT_GOAL := help
.PHONY: help


all: docker discharge zip ## make all (setup and discharge)

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

discharge: G import gates velocity export errors output figures ## Make all ice discharge

update: docker ## Update with latest Sentinel data
	scripts/update.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/errors.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/raw2discharge.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/csv2nc.py
	cp ./out/* /mnt/data/Mankoff_2020/ice/latest
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/upload.py

upload: docker ## Upload to dataverse and thredds
	cp ./out/* /mnt/data/Mankoff_2020/ice/latest
	/home/shl/miniconda3/envs/TMB/bin/python upload_cli.py --url https://thredds01.geus.dk/thredds_upload --destination sid --token $(cat ~/.new_thredds_token) --file out/*.nc
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/upload.py

docker: FORCE ## Pull down Docker environment
	docker pull mankoff/ice_discharge:grass
	${container_cmd} ${container_args} mankoff/ice_discharge:grass
	docker pull mankoff/ice_discharge:conda
	${container_cmd} ${container_args} mankoff/ice_discharge:conda conda env export -n base

G: ## Create GRASS project location
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass -e -c EPSG:3413 ./G

import: G ## Import all data to GRASS
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec scripts/import.sh

gates: import ## Find gates
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec scripts/gate_IO_runner.sh

velocity: ## Calculate effective velocity across gates
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec scripts/vel_eff.sh

export: ## Export from GRASS
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec scripts/export.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec scripts/gate_export.sh

errors: ## Calculate errors
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/errors.py

output: ## Generate CSV and NetCDF outputs
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/raw2discharge.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/csv2nc.py

figures: ## Produce figures
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/figures.py

zip: ## ZIP file of outputs
	ln -s out ice_discharge
	zip -r ice_discharge.zip ice_discharge
	rm ice_discharge

FORCE: # dummy target

clean_grass: ## Clean grass
	rm -fR G tmp out ice_discharge ice_discharge.zip

clean: clean_grass ## Clean everything
	rm -fR docker
	rm -fR __pycache__
