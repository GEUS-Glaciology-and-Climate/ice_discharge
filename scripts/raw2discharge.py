import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import datetime as dt

# pd.options.display.notebook_repr_html = False

###
### Load metadata
### 
meta_cols = ["x", "y", "err_2D", 
             "regions@Mouginot_2019", "sectors@Mouginot_2019", "gates_gateID@gates_vel_buf"]
meta = pd.read_csv("./tmp/dat_100_5000.csv", usecols=meta_cols)
# rename columns
meta.rename(inplace=True, columns={'regions@Mouginot_2019':'regions', 
                                   'sectors@Mouginot_2019':'sectors',
                                   'gates_gateID@gates_vel_buf':'gates'})
regions = {1:'NO', 2:'NE', 3:'CE', 4:'SE', 5:'SW', 6:'CW', 7:'NW'}
meta['regions'] = meta['regions'].map(regions.get) # Convert sector numbers to meaningful names
# UNDO with foo.replace({'NO':1,'NW':2,'NE':3,'CW':4,'CE':5,'SW':6,'SE':7}) 
meta['ones'] = 1

R = pd.read_csv('./out/gate_meta.csv')
meta['name'] = ''
for g in meta['gates'].unique():
    if R[R['gate'] == g].shape[0] == 0: continue
    meta.loc[meta['gates'] == g, 'name'] = R[R['gate'] == g]['Mouginot_2019'].values[0]
    
### https://github.com/GEUS-Glaciology-and-Climate/ice_discharge/issues/28
### Gates span sectors and regions. Assign to their primary sector or region
### meta.groupby('gates').mean()['sectors'].values  
### meta[meta['gates'] == 239].sectors
### Don't seem to span regions (run same code but do it above before "map(regions.get)"
for g in meta['gates'].unique():
    meta.loc[meta['gates'] == g, 'sectors'] = meta[meta['gates'] == g]['sectors'].mode()
    # meta.loc[meta['gates'] == g, 'regions'] = meta[meta['gates'] == g]['regions'].mode()

###
### Load BASELINE velocity
###
vel_baseline = pd.read_csv("./tmp/dat_100_5000.csv", usecols=['vel_baseline@MEaSUREs.0478'])
vel_baseline.rename(inplace=True, columns={'vel_baseline@MEaSUREs.0478':'vel'})

####################
# Filter Velocity: Rolling Windows
##################
def filter_bad_v(v):
    WINDOW=30
    SIGMA=2
    vel_rolling = v.T.rolling(window=WINDOW, center=True, min_periods=1).mean().T
    vel_residual = v - vel_rolling
    vel_std = vel_residual.T.rolling(window=WINDOW, center=True, min_periods=1).std().T
    vel_outlier = (v > vel_rolling+SIGMA*vel_std) | ( v < vel_rolling-SIGMA*vel_std)
    v[vel_outlier] = np.nan
    return v
####################


###
### Load all velocity
###
vel = pd.read_csv("./tmp/dat_100_5000.csv", usecols=(lambda c: ('vel_eff' in c)))


all_t = vel.rename(columns=lambda c: dt.datetime(int(c[8:12]),
                                                 int(c[13:15]),
                                                 int(c[16:18]))).columns.unique()

# 'velocity source' as in Sentinel, measures.X, measures.Y, etc.
vel_sources = np.unique([_.split('@')[1] for _ in vel.columns])
for vs in vel_sources:
    print(vs)
    vs_vel = vel.drop(labels=vel.columns[~vel.columns.str.contains(vs)], axis='columns')
    vs_vel = vs_vel.rename(columns=lambda c: dt.datetime(int(c[8:12]),
                                                         int(c[13:15]),
                                                         int(c[16:18])))\
                   .replace(0, np.nan)\
                   .sort_index(axis='columns')\
                   .reindex(all_t, axis='columns')

    vs_vel = vs_vel.loc[:,vs_vel.columns.year >= 1985] # drop early years

    # filter 3x
    vs_vel = filter_bad_v(vs_vel); vs_vel = filter_bad_v(vs_vel); vs_vel = filter_bad_v(vs_vel)

    vs_fill = vs_vel.copy() / vs_vel # 1 where data, nan where not
    vs_vel = vs_vel.interpolate(method='time', axis='columns',
                                limit_area='inside', limit_direction='both')\
                   .replace(np.nan,0)

    if vs == vel_sources[0]:
        vel_sum = vs_vel.copy()
        vel_navg = (vs_vel != 0).replace({True:1, False:0})
        vel_fill = vs_fill.copy().replace(np.nan,0)
    else:
        vel_sum += vs_vel
        vel_navg += (vs_vel.replace(np.nan,0) != 0).replace({True:1, False:0})
        vel_fill += (vs_fill.replace(np.nan,0)) # != 0).replace({True:1, False:0})

vel_final = vel_sum / vel_navg
vel_final = vel_final.fillna(method='bfill', axis=1).fillna(method='ffill', axis=1)

vel = vel_final
fill = vel_fill; fill[fill > 1] = 1


###
### Load all velocity ERROR
###
err = pd.read_csv("./tmp/dat_100_5000.csv", usecols=(lambda c: ('err_eff' in c)))
err.rename(columns=lambda c: dt.datetime(int(c[8:12]), int(c[13:15]), int(c[16:18])), inplace=True)
err.replace(0, np.nan, inplace=True)
err = err.loc[:,err.columns.year > 1985] # drop early years
err.sort_index(axis='columns', inplace=True)
err.drop(labels=err.columns[err.columns.duplicated(keep='first')], axis='columns', inplace=True)
# err.interpolate(method='time', limit_area='inside', axis=1 inplace=True)
err.fillna(method='ffill', axis=1, inplace=True)
err.fillna(method='backfill', axis=1, inplace=True)

for c in err.columns[err.columns.duplicated()]:
    err.drop(columns=c, inplace=True)

# make sure we have error (even if 0) for each velocity, and no err w/o vel
for c in vel.columns:
    if c not in err.columns:
        err[c] = np.nan

for c in err.columns:
    if c not in vel.columns:
        err.drop(columns=c, inplace=True)
    
err.sort_index(axis='columns', inplace=True)


###
### DEM
###
dem = pd.read_csv("./tmp/dat_100_5000.csv", usecols=(lambda c: ('DEM' in c)))
mv = {}
for c in dem.columns: mv[c] = int(c.split('@')[0].split('_')[1])
dem.rename(inplace=True, columns=mv)

###
### Thickness
###
th = pd.read_csv("./tmp/dat_100_5000.csv", usecols=["surface@BedMachine",
                                                    "bed@BedMachine",
                                                    "errbed@BedMachine",
                                                    "gates_gateID@gates_vel_buf"])
th.rename(inplace=True, columns={'errbed@BedMachine': 'err',
                                 'gates_gateID@gates_vel_buf':'gates'})
th['thick'] = dem[2020] - th['bed@BedMachine']


# what is the unadjusted discharge using BedMachine thickness?
D = (vel).apply(lambda c: c * (200 * th['thick'] * meta['err_2D'].values), axis=0) * 917 / 1E12
D.sum(axis='rows').resample('1D').mean().interpolate(method='time', limit_area='inside').resample('A').mean()

th['bad'] = th['thick'] <= 20

th['thick_adj_300'] = th['thick']
th['thick_adj_300_err'] = th['err']
for g in th[th['bad']]['gates'].unique(): # only work on gates with some (or all) bad thickness
    if all(th[th['gates'] == g]['bad']): # If all bad, set to 300
        th.loc[th['gates'] == g, 'thick_adj_300'] = 300
        th.loc[th['gates'] == g, 'thick_adj_300_err'] = 300/2.

    elif any(th[th['gates'] == g]['bad']): # If any bad, set to minimum of good.
        th.loc[(th['gates'] == g) & (th['bad']), 'thick_adj_300'] = \
        (th.loc[(th['gates'] == g) & (~th['bad']), 'thick']).min()
        th.loc[(th['gates'] == g) & (th['bad']), 'thick_adj_300_err'] = 300/2.

# aggressive: Anything <= 50 gets 400 m thickness
th['thick_adj_400'] = [400 if T <= 50 else T for T in th['thick']]
th['thick_adj_400_err'] = [400/2. if T[0] <= 50 else T[1] for T in zip(th['thick'],th['err'])]

D0 = (vel).apply(lambda c: c * (200 * th['thick'] * meta['err_2D'].values), axis=0) * 917 / 1E12
D1 = (vel).apply(lambda c: c * (200 * th['thick_adj_300'] * meta['err_2D'].values), axis=0) * 917 / 1E12
D0 = D0.sum(axis='rows').resample('1D').mean().interpolate(method='time', limit_area='inside').resample('A').mean()
D1 = D1.sum(axis='rows').resample('1D').mean().interpolate(method='time', limit_area='inside').resample('A').mean()
pd.concat([D0,D1, D1-D0], axis='columns', keys=['BedMachine','300','diff'])

CUTOFF = 20
df = vel_baseline.join(th['thick'])
max_vel = df.loc[df['thick'] <= CUTOFF, 'vel'].max() # limit fit to velocities where data is missing
# df = df[(df['thick'] > CUTOFF) & (df['vel'] <= max_vel)]
df = df[df['thick'] > CUTOFF]
# df = df[df['vel'] <= max_vel]

import statsmodels.api as sm
y = (df['thick'])
X = np.log10(df['vel'])
X = sm.add_constant(X)
model = sm.OLS(y, X)
fits = model.fit()
# print(fits.summary())
predictions = fits.predict(X)

from statsmodels.sandbox.regression.predstd import wls_prediction_std
XX = np.linspace(X['vel'].min(), X['vel'].max(), 50)
XX = sm.add_constant(XX)
yy = fits.predict(XX)
sdev, lower, upper = wls_prediction_std(fits, exog=XX, alpha=0.05)

# fig = plt.figure(1, figsize=(4,4)) # w,h
# # get_current_fig_manager().window.move(0,0)
# fig.clf()
# # fig.set_tight_layout(True)

# ax = fig.add_subplot(111)
# im = ax.scatter(X['vel'], y, alpha=0.1, color='k')
# xl, yl = ax.get_xlim(), ax.get_ylim()
# ax.set_ylabel('Thickness [m]')
# ax.set_xlabel('Velocity [m yr$^{-1}$]')
# ax.plot(XX[:,1], yy, 'r--')
# ax.fill_between(XX[:,1], lower, upper, color='#888888', alpha=0.4)
# ax.fill_between(XX[:,1], lower, upper, color='#888888', alpha=0.1)
# # ax.set_xlim(50,xl[1])
# ax.set_ylim(0,yl[1])
# plt.savefig('./tmp/vel_thick_fit.png', transparent=True, bbox_inches='tight', dpi=300)
# plt.savefig('./tmp/vel_thick_fit.pdf', transparent=True, bbox_inches='tight', dpi=300)
            
th['fit'] = th['thick']
vel_where_thick_bad = vel_baseline.loc[th['bad'] == True, 'vel']
th.loc[th['bad'] == True, 'fit'] = fits.predict(sm.add_constant(np.log10(vel_where_thick_bad)))
# set err to thickness where fit
th['fit_err'] = th['err']
th.loc[th['bad'] == True, 'fit_err'] = th.loc[th['bad'] == True, 'fit'] /2.


fits.summary()


D0 = (vel).apply(lambda c: c * (200 * th['thick_adj_300'] * meta['err_2D'].values), axis=0) * 917 / 1E12
D1 = (vel).apply(lambda c: c * (200 * th['fit'] * meta['err_2D'].values), axis=0) * 917 / 1E12
D0 = D0.sum(axis='rows').resample('1D').mean().interpolate(method='time', limit_area='inside').resample('A').mean()
D1 = D1.sum(axis='rows').resample('1D').mean().interpolate(method='time', limit_area='inside').resample('A').mean()
pd.concat([D0,D1, D1-D0], axis='columns', keys=['300','fit','diff'])

th[['thick','thick_adj_300','thick_adj_400','fit']].describe()

D_th = pd.DataFrame(index=th.index,
                    columns=['NoAdj','NoAdj_err','300','300_err','400','400_err','fit','fit_err'])

# + D_baseline_th_noadj :: Discharge with no thickness adjustment
D_th['NoAdj'] = vel_baseline.apply(lambda c: c * (th['thick'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

# D_baseline_th_noadj_err ::
D_th['NoAdj_err'] = vel_baseline.apply(lambda c: c * (th['err'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th['300'] = vel_baseline.apply(lambda c: c * (th['thick_adj_300'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12
D_th['300_err'] = vel_baseline.apply(lambda c: c * (th['thick_adj_300_err'].values  * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th['400'] = vel_baseline.apply(lambda c: c * (th['thick_adj_400'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12
D_th['400_err'] = vel_baseline.apply(lambda c: c * (th['thick_adj_400_err'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th['fit'] = vel_baseline.apply(lambda c: c * (th['fit'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12
D_th['fit_err'] = vel_baseline.apply(lambda c: c * (th['fit_err'].values* 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th.sum(axis=0)

dem_ts = dem.copy(deep=True)
dem_ts.columns = [str(y)+'-08-01' for y in dem_ts.columns]
dem_ts.columns = dem_ts.columns.astype(str).astype('datetime64[ns]')

# extend to first and last velocity timestamp
dem_ts[vel.columns.min()] = dem_ts[dem_ts.columns.min()]
dem_ts[vel.columns.max()] = dem_ts[dem_ts.columns.max()]
# re-sort so column are still in temporal order
dem_ts = dem_ts.reindex(sorted(dem_ts.columns), axis='columns')
# resample to daily.
dem_ts = dem_ts.T.resample('1D').interpolate().T
dem_ts = dem_ts[vel.columns] # resample back to observed times
# Above gives us DEM time series at each gate pixel


# subtract thickness from each pixel at each time
th_ts = dem_ts.apply(lambda x: x - th['bed@BedMachine'])

# Re-adjust th_ts where thickness < 20 m.
bad = th_ts.min(axis=1) < 20 # Pixels with bad thickness somewhere in the time series
for px in bad[bad == True].index:
    th_ts.loc[px] = fits.predict(np.log10([1,vel_baseline.iloc[px].values[0]]))

# D :: Discharge at pixel scale
# D_err :: The discharge error at pixel scale
# D_fill :: The fill percentage for each pixel at each point in time
D = (vel*th_ts).apply(lambda c: c * (200 * meta['err_2D'].values), axis=0) * 917 / 1E12
# Don't adjust thickness over time
# D = (vel).apply(lambda c: c * (200 * meta['err_2D'].values * th['thick'].values), axis=0) * 917 / 1E12

D_err = vel.apply(lambda c: c * (th['fit_err'] * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

[DD,DD_err] = [_.copy() for _ in [D,D_err]]
DD[['gates','sectors','regions','ones','name']] = meta[['gates','sectors','regions','ones','name']]
DD_err[['gates','sectors','regions','ones','name']] = meta[['gates','sectors','regions','ones','name']]


# D_gate :: Same, but at the gate scale
# D_gate_err ::
# D_gate_fill ::
D_gates = DD.groupby('gates').sum().drop(['ones','sectors'], axis=1)
D_gates_err = DD_err.groupby('gates').sum().drop(['ones','sectors'], axis=1)
D_gates_fill_weight = pd.DataFrame(dtype=np.float64).reindex_like(D_gates)
for g in D_gates.index:
    g_idx = (DD['gates'] == g)
    D_gates_fill_weight.loc[g] = ((D[g_idx]*fill[g_idx])/D[g_idx].sum()).sum()

D_gates.columns = D_gates.columns.astype(str).astype('datetime64[ns]')
D_gates_err.columns = D_gates_err.columns.astype(str).astype('datetime64[ns]')
D_gates_fill_weight.columns = D_gates_fill_weight.columns.astype(str).astype('datetime64[ns]')
D_gates_fill_weight.clip(lower=0, upper=1, inplace=True)



# D_sector :: Same, but at Mouginot sector scale
# D_sector_err ::
# D_sector_fill ::
D_sectors = DD.groupby('name').sum().drop(['ones','sectors','gates'], axis=1)
D_sectors_err = DD_err.groupby('name').sum().drop(['ones','sectors','gates'], axis=1)
D_sectors_fill_weight = pd.DataFrame(dtype=np.float64).reindex_like(D_sectors)
for s in D_sectors.index:
    s_idx = (DD['name'] == s)
    D_sectors_fill_weight.loc[s] = ((D[s_idx]*fill[s_idx])/D[s_idx].sum()).sum()

D_sectors.columns = D_sectors.columns.astype(str).astype('datetime64[ns]')
D_sectors_err.columns = D_sectors_err.columns.astype(str).astype('datetime64[ns]')
D_sectors_fill_weight.columns = D_sectors_fill_weight.columns.astype(str).astype('datetime64[ns]')
D_sectors_fill_weight.clip(lower=0, upper=1, inplace=True)


# D_region :: Same, but at Mouginot region scale
# D_region_err ::
# D_region_fill ::
D_regions = DD.groupby('regions').sum().drop(['ones','sectors','gates'], axis=1)
D_regions_err = DD_err.groupby('regions').sum().drop(['ones','sectors','gates'], axis=1)
D_regions_fill_weight = pd.DataFrame(dtype=np.float64).reindex_like(D_regions)
for r in D_regions.index:
    r_idx = DD['regions'] == r
    D_regions_fill_weight.loc[r] = ((D[r_idx]*fill[r_idx])/D[r_idx].sum()).sum()
    
    # # or, broken apart into simple steps.
    # # Whether any given pixel is filled (1) or not (0).
    # r_fill = fill[DD['regions'] == r].fillna(value=0)
    # # Discharge for each pixel in this region, using filling
    # r_filled_D = DD[DD['regions'] == r].drop(['sectors','regions','ones'], axis=1)
    # # weighted filling for this region
    # r_fill_weight = ((r_filled_D*r_fill)/r_filled_D.sum()).sum()
    # D_regions_fill_weight.loc[r] = r_fill_weight
    
D_regions.columns = D_regions.columns.astype(str).astype('datetime64[ns]')
D_regions_err.columns = D_regions_err.columns.astype(str).astype('datetime64[ns]')
D_regions_fill_weight.columns = D_regions_fill_weight.columns.astype(str).astype('datetime64[ns]')
D_regions_fill_weight.clip(lower=0, upper=1, inplace=True)


# D_all :: Same, but all GIS
# D_all_err ::
# D_all_fill ::
D_all = DD.drop(['regions','sectors','ones','name','gates'], axis=1).sum()
D_all_err = DD_err.drop(['regions','sectors','ones','name','gates'], axis=1).sum()
D_all_fill_weight = pd.Series(dtype=np.float64).reindex_like(D_all)
for c in D.columns:
    D_all_fill_weight.loc[c] = (fill[c] * (D[c] / D[c].sum())).sum()

STARTDATE='1986'
D_all = D_all.T[STARTDATE:].T
D_all_err = D_all_err.T[STARTDATE:].T
D_all_fill_weight = D_all_fill_weight.T[STARTDATE:].T
D_gates = D_gates.T[STARTDATE:].T
D_gates_err = D_gates_err.T[STARTDATE:].T
D_gates_fill_weight = D_gates_fill_weight.T[STARTDATE:].T
D_sectors = D_sectors.T[STARTDATE:].T
D_sectors_err = D_sectors_err.T[STARTDATE:].T
D_sectors_fill_weight = D_sectors_fill_weight.T[STARTDATE:].T
D_regions = D_regions.T[STARTDATE:].T
D_regions_err = D_regions_err.T[STARTDATE:].T
D_regions_fill_weight = D_regions_fill_weight.T[STARTDATE:].T
D_all = D_all.T[STARTDATE:].T
D_all_err = D_all_err.T[STARTDATE:].T
D_all_fill_weight = D_all_fill_weight.T[STARTDATE:].T

D_gatesT = D_gates.T
D_gates_errT = D_gates_err.T
D_gates_fill_weightT = D_gates_fill_weight.T

D_gatesT.index.name = "Date"
D_gates_errT.index.name = "Date"
D_gates_fill_weightT.index.name = "Date"

D_gatesT.to_csv('./out/gate_D.csv')
D_gates_errT.to_csv('./out/gate_err.csv')
D_gates_fill_weightT.to_csv('./out/gate_coverage.csv')

# meta_sector = pd.DataFrame(index=meta.groupby('sectors').first().index)
# meta_sector['mean x'] = meta.groupby('sectors').mean()['x'].round().astype(int)
# meta_sector['mean y'] = meta.groupby('sectors').mean()['y'].round().astype(int)
# meta_sector['n gates'] = meta.groupby('sectors').count()['gates'].round().astype(int)
# meta_sector['region'] = meta.groupby('sectors').first()['regions']

D_sectorsT = D_sectors.T
D_sectors_errT = D_sectors_err.T
D_sectors_fill_weightT = D_sectors_fill_weight.T

D_sectorsT.index.name = "Date"
D_sectors_errT.index.name = "Date"
D_sectors_fill_weightT.index.name = "Date"

# meta_sector.to_csv('./out/sector_meta.csv')
D_sectorsT.to_csv('./out/sector_D.csv')
D_sectors_errT.to_csv('./out/sector_err.csv')
D_sectors_fill_weightT.to_csv('./out/sector_coverage.csv')

# meta_sector.head(10)

# meta_region = pd.DataFrame(index=meta.groupby('regions').first().index)
# meta_region['n gates'] = meta.groupby('regions').count()['gates'].round().astype(int)

D_regionsT = D_regions.T
D_regions_errT = D_regions_err.T
D_regions_fill_weightT = D_regions_fill_weight.T
D_regionsT.index.name = "Date"
D_regions_errT.index.name = "Date"
D_regions_fill_weightT.index.name = "Date"

# meta_region.to_csv('./out/region_meta.csv')
D_regionsT.to_csv('./out/region_D.csv')
D_regions_errT.to_csv('./out/region_err.csv')
D_regions_fill_weightT.to_csv('./out/region_coverage.csv')

# meta_region.head(10)

D_all.index.name = "Date"
D_all_err.index.name = "Date"
D_all_fill_weight.index.name = "Date"

D_all.to_csv('./out/GIS_D.csv', float_format='%.3f', header=["Discharge [Gt yr-1]"])
D_all_err.to_csv('./out/GIS_err.csv', float_format='%.3f', header=["Discharge Error [Gt yr-1]"])
D_all_fill_weight.to_csv('./out/GIS_coverage.csv', float_format='%.3f', header=["Coverage [unit]"])
