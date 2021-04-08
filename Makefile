all: G run dist

G:
	grass -e -c EPSG:3413 ./G

run: FORCE
	grass ./G/PERMANENT --exec ./import.sh
	grass ./G/PERMANENT --exec ./gate_IO_runner.sh
	grass ./G/PERMANENT --exec ./vel_eff.sh
	grass ./G/PERMANENT --exec ./export.sh
	python ./errors.py
	python ./raw2discharge.py
	python ./csv2nc.py
	grass ./G/PERMANENT --exec ./gate_export.sh
	python ./figures.py

dist:
	ln -s out ice_discharge
	zip -r ice_discharge.zip ice_discharge
	rm ice_discharge

FORCE: # dummy target

clean:
	rm -fR G tmp out ice_discharge.zip
