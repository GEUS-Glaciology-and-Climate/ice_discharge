import pandas as pd
import xarray as xr
import numpy as np
import subprocess
import datetime

csvfile = 'GIS'

df_D = pd.read_csv('./out/' + csvfile + '_D.csv', index_col=0, parse_dates=True)
df_err = pd.read_csv('./out/' + csvfile + '_err.csv', index_col=0, parse_dates=True)
df_coverage = pd.read_csv('./out/' + csvfile + '_coverage.csv', index_col=0, parse_dates=True)

# ds = df_D.to_xarray()

# ds = xr.Dataset({'time': df_D})
ds = xr.Dataset()

ds["time"] = ("time", df_D.index)
ds["time"].attrs["long_name"] = "time of measurement"
ds["time"].attrs["standard_name"] = "time"
ds["time"].attrs["axis"] = "T"
ds["time"].attrs["cf_role"] = "timeseries_id"

ds["discharge"] = ("time", df_D['Discharge [Gt yr-1]'])
ds["discharge"].attrs["long_name"] = "Discharge"
ds["discharge"].attrs["standard_name"] = "land_ice_mass_tranport_due_to_calving_and_ice_front_melting"
ds["discharge"].attrs["units"] = "Gt yr-1"
ds["discharge"].attrs["coordinates"] = "time"

ds["err"] = ("time", df_err['Discharge Error [Gt yr-1]'])
ds["err"].attrs["long_name"] = "Error"
ds["err"].attrs["standard_name"] = "Uncertainty"
ds["err"].attrs["units"] = "Gt yr-1"
ds["err"].attrs["coordinates"] = "time"

ds["coverage"] = ("time", df_coverage['Coverage [unit]'])
ds["coverage"].attrs["long_name"] = "Coverage"
ds["coverage"].attrs["standard_name"] = "Coverage"
# ds["coverage"].attrs["units"] = "-"
ds["coverage"].attrs["coordinates"] = "time"

ds.attrs["featureType"] = "timeSeries"
ds.attrs["title"] = "Greenland discharge"
ds.attrs["summary"] = "Greenland discharge"
ds.attrs["keywords"] = "Greenland; Ice Discharge; Calving; Submarine Melt"
# ds.attrs["Conventions"] = "CF-1.8"
ds.attrs["source"] = "git commit: " + subprocess.check_output(["git", "describe", "--always"]).strip().decode('UTF-8')
# ds.attrs["comment"] = "TODO"
# ds.attrs["acknowledgment"] = "TODO"
# ds.attrs["license"] = "TODO"
# ds.attrs["date_created"] = datetime.datetime.now().strftime("%Y-%m-%d")
ds.attrs["creator_name"] = "Ken Mankoff"
ds.attrs["creator_email"] = "kdm@geus.dk"
ds.attrs["creator_url"] = "http://kenmankoff.com"
ds.attrs["institution"] = "GEUS"
# ds.attrs["time_coverage_start"] = "TODO"
# ds.attrs["time_coverage_end"] = "TODO"
# ds.attrs["time_coverage_resolution"] = "TODO"
ds.attrs["references"] = "10.22008/promice/ice_discharge"
ds.attrs["product_version"] = 2.0

# NOTE: Compression here does not save space
# comp = dict(zlib=True, complevel=5)
# encoding = {var: comp for var in ds.data_vars} # all
# encoding = {var: comp for var in ['time','coverage']} # some

ds.to_netcdf('./out/GIS.nc', mode='w')#, encoding=encoding)

csvfile = 'region'

df_D = pd.read_csv('./out/' + csvfile + '_D.csv', index_col=0, parse_dates=True)
df_err = pd.read_csv('./out/' + csvfile + '_err.csv', index_col=0, parse_dates=True)
df_coverage = pd.read_csv('./out/' + csvfile + '_coverage.csv', index_col=0, parse_dates=True)

ds = xr.Dataset()

ds["time"] = (("time"), df_D.index)
ds["time"].attrs["cf_role"] = "timeseries_id"
ds["time"].attrs["standard_name"] = "time"
# ds["time"].attrs["units"] = "day of year"
# ds["time"].attrs["calendar"] = "julian"
ds["time"].attrs["axis"] = "T"

ds["region"] = (("region"), df_D.columns)
ds["region"].attrs["long_name"] = "Region"
ds["region"].attrs["standard_name"] = "N/A"
ds["region"].attrs["comment"] = "Regions from Mouginot (2019)"

ds["discharge"] = (("region", "time"), df_D.T.values)
ds["discharge"].attrs["long_name"] = "Discharge"
ds["discharge"].attrs["standard_name"] = "land_ice_mass_tranport_due_to_calving_and_ice_front_melting"
ds["discharge"].attrs["units"] = "Gt yr-1"
ds["discharge"].attrs["coordinates"] = "time region"

ds["err"] = (("region", "time"), df_err.T.values)
ds["err"].attrs["long_name"] = "Error"
ds["err"].attrs["standard_name"] = "Uncertainty"
ds["err"].attrs["units"] = "Gt yr-1"
ds["err"].attrs["coordinates"] = "time region"

ds["coverage"] = (("region", "time"), df_coverage.T.values)
ds["coverage"].attrs["long_name"] = "Coverage"
ds["coverage"].attrs["standard_name"] = "Coverage"
# ds["coverage"].attrs["units"] = "-"
ds["coverage"].attrs["coordinates"] = "time region"

# ds["lat"] = (("station"), meta.loc['lat'].astype(np.float32))
# #ds["lat"].attrs["coordinates"] = "station"
# ds["lat"].attrs["long_name"] = "latitude"
# ds["lat"].attrs["standard_name"] = "latitude"
# ds["lat"].attrs["units"] = "degrees_north"
# ds["lat"].attrs["axis"] = "Y"

# ds["lon"] = (("station"), meta.loc['lon'].astype(np.float32))
# #ds["lon"].attrs["coordinates"] = "station"
# ds["lon"].attrs["long_name"] = "longitude"
# ds["lon"].attrs["standard_name"] = "longitude"
# ds["lon"].attrs["units"] = "degrees_east"
# ds["lon"].attrs["axis"] = "X"

# ds["alt"] = (("station"), meta.loc['elev'].astype(np.float32))
# ds["alt"].attrs["long_name"] = "height_above_mean_sea_level"
# ds["alt"].attrs["standard_name"] = "altitude"
# # ds["alt"].attrs["long_name"] = "height above mean sea level"
# # ds["alt"].attrs["standard_name"] = "height"
# ds["alt"].attrs["units"] = "m"
# ds["alt"].attrs["positive"] = "up"
# ds["alt"].attrs["axis"] = "Z"

ds.attrs["featureType"] = "timeSeries"
ds.attrs["title"] = "Greenland discharge"
ds.attrs["summary"] = "Greenland discharge per region"
ds.attrs["keywords"] = "Greenland; Ice Discharge; Calving; Submarine Melt"
# ds.attrs["Conventions"] = "CF-1.8"
ds.attrs["source"] = "git commit: " + subprocess.check_output(["git", "describe", "--always"]).strip().decode('UTF-8')
# ds.attrs["comment"] = "TODO"
# ds.attrs["acknowledgment"] = "TODO"
# ds.attrs["license"] = "TODO"
# ds.attrs["date_created"] = datetime.datetime.now().strftime("%Y-%m-%d")
ds.attrs["creator_name"] = "Ken Mankoff"
ds.attrs["creator_email"] = "kdm@geus.dk"
ds.attrs["creator_url"] = "http://kenmankoff.com"
ds.attrs["institution"] = "GEUS"
# ds.attrs["time_coverage_start"] = "TODO"
# ds.attrs["time_coverage_end"] = "TODO"
# ds.attrs["time_coverage_resolution"] = "TODO"
ds.attrs["references"] = "10.22008/promice/ice_discharge"
ds.attrs["product_version"] = 2.0

comp = dict(zlib=True, complevel=9)
encoding = {var: comp for var in ds.data_vars} # all

ds.to_netcdf('./out/region.nc', mode='w', encoding=encoding)

csvfile = 'sector'

df_D = pd.read_csv('./out/' + csvfile + '_D.csv', index_col=0, parse_dates=True)
df_err = pd.read_csv('./out/' + csvfile + '_err.csv', index_col=0, parse_dates=True)
df_coverage = pd.read_csv('./out/' + csvfile + '_coverage.csv', index_col=0, parse_dates=True)

ds = xr.Dataset()

ds["time"] = (("time"), df_D.index)
ds["time"].attrs["cf_role"] = "timeseries_id"
ds["time"].attrs["standard_name"] = "time"
# ds["time"].attrs["units"] = "day of year"
# ds["time"].attrs["calendar"] = "julian"
ds["time"].attrs["axis"] = "T"

ds["sector"] = (("sector"), df_D.columns)
ds["sector"].attrs["long_name"] = "Sector"
ds["sector"].attrs["standard_name"] = "N/A"
ds["sector"].attrs["comment"] = "Sectors from Mouginot (2019)"

ds["discharge"] = (("sector", "time"), df_D.T.values)
ds["discharge"].attrs["long_name"] = "Discharge"
ds["discharge"].attrs["standard_name"] = "land_ice_mass_tranport_due_to_calving_and_ice_front_melting"
ds["discharge"].attrs["units"] = "Gt yr-1"
ds["discharge"].attrs["coordinates"] = "time sector"

ds["err"] = (("sector", "time"), df_err.T.values)
ds["err"].attrs["long_name"] = "Error"
ds["err"].attrs["standard_name"] = "Uncertainty"
ds["err"].attrs["units"] = "Gt yr-1"
ds["err"].attrs["coordinates"] = "time sector"

ds["coverage"] = (("sector", "time"), df_coverage.T.values)
ds["coverage"].attrs["long_name"] = "Coverage"
ds["coverage"].attrs["standard_name"] = "Coverage"
# ds["coverage"].attrs["units"] = "-"
ds["coverage"].attrs["coordinates"] = "time sector"

# ds["lat"] = (("station"), meta.loc['lat'].astype(np.float32))
# #ds["lat"].attrs["coordinates"] = "station"
# ds["lat"].attrs["long_name"] = "latitude"
# ds["lat"].attrs["standard_name"] = "latitude"
# ds["lat"].attrs["units"] = "degrees_north"
# ds["lat"].attrs["axis"] = "Y"

# ds["lon"] = (("station"), meta.loc['lon'].astype(np.float32))
# #ds["lon"].attrs["coordinates"] = "station"
# ds["lon"].attrs["long_name"] = "longitude"
# ds["lon"].attrs["standard_name"] = "longitude"
# ds["lon"].attrs["units"] = "degrees_east"
# ds["lon"].attrs["axis"] = "X"

# ds["alt"] = (("station"), meta.loc['elev'].astype(np.float32))
# ds["alt"].attrs["long_name"] = "height_above_mean_sea_level"
# ds["alt"].attrs["standard_name"] = "altitude"
# # ds["alt"].attrs["long_name"] = "height above mean sea level"
# # ds["alt"].attrs["standard_name"] = "height"
# ds["alt"].attrs["units"] = "m"
# ds["alt"].attrs["positive"] = "up"
# ds["alt"].attrs["axis"] = "Z"

ds.attrs["featureType"] = "timeSeries"
ds.attrs["title"] = "Greenland discharge"
ds.attrs["summary"] = "Greenland discharge per sector"
ds.attrs["keywords"] = "Greenland; Ice Discharge; Calving; Submarine Melt"
# ds.attrs["Conventions"] = "CF-1.8"
ds.attrs["source"] = "git commit: " + subprocess.check_output(["git", "describe", "--always"]).strip().decode('UTF-8')
# ds.attrs["comment"] = "TODO"
# ds.attrs["acknowledgment"] = "TODO"
# ds.attrs["license"] = "TODO"
# ds.attrs["date_created"] = datetime.datetime.now().strftime("%Y-%m-%d")
ds.attrs["creator_name"] = "Ken Mankoff"
ds.attrs["creator_email"] = "kdm@geus.dk"
ds.attrs["creator_url"] = "http://kenmankoff.com"
ds.attrs["institution"] = "GEUS"
# ds.attrs["time_coverage_start"] = "TODO"
# ds.attrs["time_coverage_end"] = "TODO"
# ds.attrs["time_coverage_resolution"] = "TODO"
ds.attrs["references"] = "10.22008/promice/ice_discharge"
ds.attrs["product_version"] = 2.0

comp = dict(zlib=True, complevel=9)
encoding = {var: comp for var in ds.data_vars} # all

ds.to_netcdf('./out/sector.nc', mode='w', encoding=encoding)

csvfile = 'gate'

df_D = pd.read_csv('./out/' + csvfile + '_D.csv', index_col=0, parse_dates=True)
df_err = pd.read_csv('./out/' + csvfile + '_err.csv', index_col=0, parse_dates=True)
df_coverage = pd.read_csv('./out/' + csvfile + '_coverage.csv', index_col=0, parse_dates=True)

meta = pd.read_csv("./out/gate_meta.csv")

ds = xr.Dataset()

ds["time"] = (("time"), df_D.index)
ds["time"].attrs["cf_role"] = "timeseries_id"
ds["time"].attrs["standard_name"] = "time"
# ds["time"].attrs["units"] = "day of year"
# ds["time"].attrs["calendar"] = "julian"
ds["time"].attrs["axis"] = "T"

ds["gate"] = (("gate"), df_D.columns.astype(np.int32))
ds["gate"].attrs["long_name"] = "Gate"
ds["gate"].attrs["standard_name"] = "N/A"

ds["discharge"] = (("gate", "time"), df_D.T.values.astype(np.float32))
ds["discharge"].attrs["long_name"] = "Discharge"
ds["discharge"].attrs["standard_name"] = "land_ice_mass_tranport_due_to_calving_and_ice_front_melting"
ds["discharge"].attrs["units"] = "Gt yr-1"
ds["discharge"].attrs["coordinates"] = "time gate"

ds["err"] = (("gate", "time"), df_err.T.values.astype(np.float32))
ds["err"].attrs["long_name"] = "Error"
ds["err"].attrs["standard_name"] = "Uncertainty"
ds["err"].attrs["units"] = "Gt yr-1"
ds["err"].attrs["coordinates"] = "time gate"

ds["coverage"] = (("gate", "time"), df_coverage.T.values.astype(np.float32))
ds["coverage"].attrs["long_name"] = "Coverage"
ds["coverage"].attrs["standard_name"] = "Coverage"
# ds["coverage"].attrs["units"] = "-"
ds["coverage"].attrs["coordinates"] = "time gate"

ds["mean_x"] = (("gate"), meta.mean_x.astype(np.int32))
ds["mean_x"].attrs["long_name"] = "Mean x coordinate of gate in EPSG:3413"
ds["mean_x"].attrs["standard_name"] = "Mean x"

ds["mean_y"] = (("gate"), meta.mean_y.astype(np.int32))
ds["mean_y"].attrs["long_name"] = "Mean y coordinate of gate in EPSG:3413"
ds["mean_y"].attrs["standard_name"] = "Mean y"

ds["mean_lon"] = (("gate"), meta.lon.astype(np.float32))
ds["mean_lon"].attrs["long_name"] = "Mean lon coordinate of gate"
ds["mean_lon"].attrs["standard_name"] = "Longitude"

ds["mean_lat"] = (("gate"), meta.lat.astype(np.float32))
ds["mean_lat"].attrs["long_name"] = "Mean lat coordinate of gate"
ds["mean_lat"].attrs["standard_name"] = "Latitude"

ds["sector"] = (("gate"), meta.sector.astype(np.int32))
ds["sector"].attrs["long_name"] = "Mouginot 2019 sector containing gate"

ds["region"] = (("gate"), meta.region)
ds["region"].attrs["long_name"] = "Mouginot 2019 region containing gate"

ds["Zwally_2012"] = (("gate"), meta.Zwally_2012)
ds["Zwally_2012"].attrs["long_name"] = "Zwally 2012 sector containing gate"

ds["name_Bjørk"] = (("gate"), meta.Bjork_2015)
ds["name_Bjørk"].attrs["long_name"] = "Nearest name from Bjørk (2015)"

ds["name_Mouginot"] = (("gate"), meta.Mouginot_2019)
ds["name_Mouginot"].attrs["long_name"] = "Nearest name from Mouginot (2019)"

ds.attrs["featureType"] = "timeSeries"
ds.attrs["title"] = "Greenland discharge"
ds.attrs["summary"] = "Greenland discharge per gate"
ds.attrs["keywords"] = "Greenland; Ice Discharge; Calving; Submarine Melt"
# ds.attrs["Conventions"] = "CF-1.8"
ds.attrs["source"] = "git commit: " + subprocess.check_output(["git", "describe", "--always"]).strip().decode('UTF-8')
# ds.attrs["comment"] = "TODO"
# ds.attrs["acknowledgment"] = "TODO"
# ds.attrs["license"] = "TODO"
# ds.attrs["date_created"] = datetime.datetime.now().strftime("%Y-%m-%d")
ds.attrs["creator_name"] = "Ken Mankoff"
ds.attrs["creator_email"] = "kdm@geus.dk"
ds.attrs["creator_url"] = "http://kenmankoff.com"
ds.attrs["institution"] = "GEUS"
# ds.attrs["time_coverage_start"] = "TODO"
# ds.attrs["time_coverage_end"] = "TODO"
# ds.attrs["time_coverage_resolution"] = "TODO"
ds.attrs["references"] = "10.22008/promice/ice_discharge"
ds.attrs["product_version"] = 2.0

comp = dict(zlib=True, complevel=9)
encoding = {var: comp for var in ds.data_vars} # all

ds.to_netcdf('./out/gate.nc', mode='w', encoding=encoding)
