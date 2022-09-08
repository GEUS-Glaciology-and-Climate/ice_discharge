container_cmd ?= docker
container_args ?= run --user $(shell id -u):$(shell id -g) --mount type=bind,src=$${DATADIR},dst=/data --mount type=bind,src=$(shell pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1"

org-babel = emacsclient --eval "(progn                  \
        (find-file \"$(1)\")                            \
        (org-babel-goto-named-src-block \"$(2)\")       \
        (org-babel-execute-src-block)                   \
        (save-buffer))"
# Usage: $(call org-babel,<file.org>,<named_babel_block>)

SHELL = bash
.DEFAULT_GOAL := help
.PHONY: help
TANGLED := $(shell grep -Eo ":tangle.*" ice_discharge.org | cut -d" " -f2 | grep -Ev 'identity|no')


all: docker tangle discharge zip #org ## make all (setup and discharge)

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

discharge: G import gates velocity export errors output figures ## Make all ice discharge

update: docker ## Update with latest Sentinel data
	./update.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./errors.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./raw2discharge.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./csv2nc.py
	cp ./out/* ~/data/Mankoff_2020/ice/latest
	#make org
	#/usr/bin/git pull
	#/usr/bin/git commit ice_discharge.org -m "Auto update: `/bin/date +%Y-%m-%d\ %T`"
	#/usr/bin/git push
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./upload.py


org: ## Update the Org document
	# use emacsclient --eval to run in existing Emacs.
	# If running new emacs, don't use -Q because I need my ~/.emacs.d/init.el loaded
	emacs --batch -l emacs.el --eval "(progn \
	(find-file \"ice_discharge.org\") \
	(org-babel-map-src-blocks nil (if (org-babel-where-is-src-block-result)  \
					(org-babel-insert-result \"\" '(\"replace\")))) \
	(save-buffer) (org-babel-execute-buffer) (save-buffer) (kill-emacs))"

docker: FORCE ## Pull down Docker environment
	docker pull mankoff/ice_discharge:grass
	${container_cmd} ${container_args} mankoff/ice_discharge:grass
	docker pull mankoff/ice_discharge:conda
	${container_cmd} ${container_args} mankoff/ice_discharge:conda conda env export -n base

tangle: ## Tangle code from source Org file using Emacs
	emacs -Q --batch --eval "(progn (find-file \"ice_discharge.org\") (org-babel-tangle))"

G: ## Create GRASS project location
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass -e -c EPSG:3413 ./G

import: G ## Import all data to GRASS
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./import.sh

gates: import ## Find gates
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./gate_IO_runner.sh

velocity: ## Calculate effective velocity across gates
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./vel_eff.sh

export: ## Export from GRASS
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./export.sh
	${container_cmd} ${container_args} mankoff/ice_discharge:grass grass ./G/PERMANENT --exec ./gate_export.sh

errors: ## Calculate errors
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./errors.py

output: ## Generate CSV and NetCDF outputs
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./raw2discharge.py
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./csv2nc.py

figures: ## Produce figures
	${container_cmd} ${container_args} mankoff/ice_discharge:conda python ./figures.py

zip: ## ZIP file of outputs
	ln -s out ice_discharge
	zip -r ice_discharge.zip ice_discharge
	rm ice_discharge

FORCE: # dummy target

clean_org: ## Update the Org document
        # use emacsclient --eval to run in existing Emacs.
        # If running new emacs, don't use -Q because I need my ~/.emacs.d/init.el loaded
	emacs --batch -l emacs.el --eval "(progn \
	(find-file \"ice_discharge.org\") \
	(org-babel-map-src-blocks nil (if (org-babel-where-is-src-block-result)  \
	                                (org-babel-insert-result \"\" '(\"replace\")))) \
	(save-buffer) (kill-emacs))"

clean_grass: ## Clean grass
	rm -fR G tmp out ice_discharge ice_discharge.zip

clean: clean_grass ## Clean everything
	rm -fR docker
	rm -fR __pycache__
	@echo cleaning: $(TANGLED) environment.yml
	rm -fr $(TANGLED) environment.yml
