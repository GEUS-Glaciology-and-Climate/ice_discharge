container_cmd ?= docker
container_args ?= run -it --user $(shell id -u):$(shell id -g) --mount type=bind,src=$${DATADIR},dst=/data --mount type=bind,src=$(shell pwd),dst=/work --env PARALLEL="--delay 0.1 -j -1"

all: setup G run dist

setup: ## Set up environment
	docker pull mankoff/ice_discharge:grass
	${container_cmd} ${container_args} mankoff/ice_discharge:grass

G:
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass -e -c EPSG:3413 ./G

run: FORCE
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./import.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./gate_IO_runner.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./vel_eff.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./export.sh
	python ./errors.py
	python ./raw2discharge.py
	python ./csv2nc.py
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./gate_export.sh
	python ./figures.py

dist:
	ln -s out ice_discharge
	zip -r ice_discharge.zip ice_discharge
	rm ice_discharge

FORCE: # dummy target

clean:
	rm -fR G tmp out ice_discharge.zip
