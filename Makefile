container_cmd ?= docker
container_args ?= run --user $(shell id -u):$(shell id -g) --mount type=bind,src=$${DATADIR},dst=/data --mount type=bind,src=$(shell pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1"
grass_exec = ${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec

SHELL = bash
.DEFAULT_GOAL := help
.PHONY: help all discharge update upload docker gates velocity export errors output figures zip clean clean_grass

STAMPS := .stamps

$(STAMPS):
	mkdir -p $(STAMPS)


all: docker discharge zip ## Make all (setup and discharge)

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

discharge: G import gates velocity export errors output figures ## Run the full discharge pipeline

update: docker ## Update with latest Sentinel data
	scripts/update.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/errors.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/raw2discharge.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/csv2nc.py
	cp ./out/* /mnt/data/Mankoff_2020/ice/latest
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/upload.py

upload: docker ## Upload to dataverse and thredds
	cp ./out/* /mnt/data/Mankoff_2020/ice/latest
	/home/shl/miniconda3/envs/TMB/bin/python upload_cli.py --url https://thredds01.geus.dk/thredds_upload --destination sid --token $$(cat ~/.new_thredds_token) --file out/*.nc
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/upload.py

docker: ## Pull down Docker images
	docker pull mankoff/ice_discharge:grass
	${container_cmd} ${container_args} mankoff/ice_discharge:grass
	docker pull mankoff/ice_discharge:conda
	${container_cmd} ${container_args} mankoff/ice_discharge:conda conda env export -n base

G: ## Create GRASS project location
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass -e -c EPSG:3413 ./G


## --- Import targets (stamp-based: each step runs only when its script changes) ---

import: ## Import all data into GRASS
import: $(STAMPS)/import_bedmachine \
        $(STAMPS)/import_basins \
        $(STAMPS)/import_area_error \
        $(STAMPS)/import_measures_0478 \
        $(STAMPS)/import_measures_0481 \
        $(STAMPS)/import_measures_0646 \
        $(STAMPS)/import_measures_0731 \
        $(STAMPS)/import_measures_0766 \
        $(STAMPS)/import_promice \
        $(STAMPS)/import_mouginot_pre2000 \
        $(STAMPS)/import_dem

# BedMachine must run first — it sets the PERMANENT region all other imports use
$(STAMPS)/import_bedmachine: scripts/import_bedmachine.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_bedmachine.sh
	touch $@

# area_error depends on import_bedmachine having set the PERMANENT region
$(STAMPS)/import_area_error: scripts/import_area_error.sh scripts/common.sh $(STAMPS)/import_bedmachine | $(STAMPS)
	${grass_exec} scripts/import_area_error.sh
	touch $@

$(STAMPS)/import_basins: scripts/import_basins.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_basins.sh
	touch $@

$(STAMPS)/import_measures_0478: scripts/import_measures_0478.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_measures_0478.sh
	touch $@

$(STAMPS)/import_measures_0481: scripts/import_measures_0481.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_measures_0481.sh
	touch $@

$(STAMPS)/import_measures_0646: scripts/import_measures_0646.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_measures_0646.sh
	touch $@

$(STAMPS)/import_measures_0731: scripts/import_measures_0731.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_measures_0731.sh
	touch $@

$(STAMPS)/import_measures_0766: scripts/import_measures_0766.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_measures_0766.sh
	touch $@

$(STAMPS)/import_promice: scripts/import_promice.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_promice.sh
	touch $@

$(STAMPS)/import_mouginot_pre2000: scripts/import_mouginot_pre2000.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_mouginot_pre2000.sh
	touch $@

# import_dem depends on PRODEM and Khan data (both inside this script)
$(STAMPS)/import_dem: scripts/import_dem.sh scripts/common.sh | G $(STAMPS)
	${grass_exec} scripts/import_dem.sh
	touch $@


## --- Downstream targets ---

gates: import ## Find flux gates
	${grass_exec} scripts/gate_IO_runner.sh

velocity: ## Compute effective velocity at each gate
	${grass_exec} scripts/vel_eff.sh

export: ## Export pixel-level data from GRASS to CSV
	${grass_exec} scripts/export.sh
	${grass_exec} scripts/gate_export.sh

errors: ## Estimate discharge errors
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/errors.py

output: ## Compute discharge and write NetCDF
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/raw2discharge.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/csv2nc.py

figures: ## Produce figures
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python scripts/figures.py

zip: ## ZIP output directory
	ln -s out ice_discharge
	zip -r ice_discharge.zip ice_discharge
	rm ice_discharge

clean_grass: ## Remove GRASS database and all generated files
	rm -fR G tmp out ice_discharge ice_discharge.zip .stamps

clean: clean_grass ## Remove everything including Docker cache and pycache
	rm -fR docker
	rm -fR __pycache__
