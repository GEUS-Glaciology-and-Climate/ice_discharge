import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import datetime as dt

# pd.options.display.notebook_repr_html = False

###
### Load metadata
### 
meta_cols = ["x", "y", "err_2D", 
             "regions@Mouginot_2019", "sectors@Mouginot_2019", "gates_gateID@gates_100_5000"]
meta = pd.read_csv("./tmp/dat_100_5000.csv", usecols=meta_cols)
# rename columns
meta.rename(inplace=True, columns={'regions@Mouginot_2019':'regions', 
                                   'sectors@Mouginot_2019':'sectors',
                                   'gates_gateID@gates_100_5000':'gates'})
regions = {1:'NO', 2:'NE', 3:'CE', 4:'SE', 5:'SW', 6:'CW', 7:'NW'}
meta['regions'] = meta['regions'].map(regions.get) # Convert sector numbers to meaningful names
meta['ones'] = 1

R = pd.read_csv('./out/gate_meta.csv')
meta['name'] = ''
for g in meta['gates'].unique(): meta.loc[meta['gates'] == g, 'name'] = R[R['gate'] == g]['Mouginot_2019'].values

###
### Load BASELINE velocity
###
vel_baseline = pd.read_csv("./tmp/dat_100_5000.csv", usecols=['vel_baseline@MEaSUREs.0478'])
vel_baseline.rename(inplace=True, columns={'vel_baseline@MEaSUREs.0478':'vel'})

###
### Load all velocity
###
vel = pd.read_csv("./tmp/dat_100_5000.csv", usecols=(lambda c: ('vel_eff' in c)))
vel.rename(columns=lambda c: dt.datetime(int(c[8:12]), int(c[13:15]), int(c[16:18])), inplace=True)
# vel.drop(columns=dt.datetime(1999, 7, 1), inplace=True) # bad year?
vel.replace(0, np.nan, inplace=True)
# vel = vel.loc[:,vel.columns.year < 2018] # drop 2018
vel = vel.loc[:,vel.columns.year >= 1985] # drop early years
vel.sort_index(axis='columns', inplace=True)
vel.drop(labels=vel.columns[vel.columns.duplicated(keep='first')], axis='columns', inplace=True)

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
vel = filter_bad_v(vel)
vel = filter_bad_v(vel)
vel = filter_bad_v(vel)

fill = vel.copy() / vel # 1 where data, nan where not

vel = vel.interpolate(method='time', axis='columns', limit_area='inside', limit_direction='both')
vel.fillna(method='ffill', axis=1, inplace=True)
vel.fillna(method='bfill', axis=1, inplace=True)

# vel[meta.name == TESTNAME].T.sort_index().head()
# fill[meta.name == TESTNAME].T.sort_index().head()

# vel.sum(axis='rows').resample('1D').mean().interpolate(method='time', limit_area='inside').resample('A').mean()/1E6


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

# tmp = np.array([c if c not in err.columns else None for c in vel.columns]); print(tmp[tmp != None])


###
### Thickness
###
th = pd.read_csv("./tmp/dat_100_5000.csv", usecols=["thickness@BedMachine",
                                           "surface@BedMachine",
                                           "bed@BedMachine",
                                           "errbed@BedMachine",
                                           "gates_gateID@gates_100_5000"])
th.rename(inplace=True, columns={'thickness@BedMachine':'thick',
                                 'errbed@BedMachine': 'err',
                                 'gates_gateID@gates_100_5000':'gates'})
th_GIMP = pd.read_csv("./tmp/dat_100_5000.csv", usecols=(lambda c: ('@GIMP.0715' in c)))
th_GIMP['day'] = [dt.datetime(2000,1,1) + dt.timedelta(days=np.int(_)) for _ in th_GIMP['day@GIMP.0715']]
for _ in th_GIMP.columns: th[_] = th_GIMP[_]
del(th_GIMP)


###
### dh/dt
###
dhdt = pd.read_csv("./tmp/dat_100_5000.csv", usecols=(lambda c: ('dh' in c)))
mv = {}
for c in dhdt.columns: mv[c] = np.int(c.split('@')[0].split('_')[1])
dhdt.rename(inplace=True, columns=mv)

# assume trend continues from last measured value
dhdt[2020] = dhdt[2019]
dhdt[2021] = dhdt[2020]
for y in np.arange(1985,1994+1): dhdt[y] = dhdt.loc[:,1995:1997].mean(axis='columns')
dhdt.sort_index(axis='columns', inplace=True)

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

# should match HeatMap
D_th['NoMillan'] = vel_baseline.apply(lambda c: c * ((th['surface@BedMachine']-th['bed@BedMachine']).values * 200), axis=0) * 917 / 1E12

# D_baseline_th_noadj_err ::
D_th['NoAdj_err'] = vel_baseline.apply(lambda c: c * (th['err'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th['300'] = vel_baseline.apply(lambda c: c * (th['thick_adj_300'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12
D_th['300_err'] = vel_baseline.apply(lambda c: c * (th['thick_adj_300_err'].values  * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th['400'] = vel_baseline.apply(lambda c: c * (th['thick_adj_400'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12
D_th['400_err'] = vel_baseline.apply(lambda c: c * (th['thick_adj_400_err'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th['fit'] = vel_baseline.apply(lambda c: c * (th['fit'].values * 200 * meta['err_2D'].values), axis=0) * 917 / 1E12
D_th['fit_err'] = vel_baseline.apply(lambda c: c * (th['fit_err'].values* 200 * meta['err_2D'].values), axis=0) * 917 / 1E12

D_th.sum(axis=0)

dhdt_ts = dhdt.copy(deep=True)
# dhdt_ts[2016] = dhdt_ts[2015] # assume annual dh/dt continues at fixed rate
# dhdt_ts[2017] = dhdt_ts[2015]
# dhdt_ts[2018] = dhdt_ts[2015]
# dhdt_ts[2016] = 0
# dhdt_ts[2017] = 0
# dhdt_ts[2018] = 0
dhdt_ts[dhdt.columns.max()+1] = 0
dhdt_ts = dhdt_ts.reindex(sorted(dhdt_ts.columns), axis='columns')
dhdt_ts = dhdt_ts.cumsum(axis='columns')
dhdt_ts.columns = dhdt_ts.columns.astype(np.str).astype('datetime64[ns]')
dhdt_ts = dhdt_ts.T.resample('1D').interpolate().T
# from above: daily accumulated change at each discharge pixel for SEC time series

# expand from SEC 1st time to velocity 1st time, assuming no changes in SEC
dhdt_ts[dhdt_ts.columns.min()] = dhdt_ts[dhdt_ts.columns.min()]
dhdt_ts[vel.columns.min()] = dhdt_ts[dhdt_ts.columns.min()]
dhdt_ts = dhdt_ts.T.resample('1D').interpolate().T

th_ts = pd.DataFrame().reindex_like(dhdt_ts)
for idx in th.index:
    t0_pix = th.loc[idx]
    # adjusted thickness at t0_pix['day']
    t0_pix_th = t0_pix['fit'] + (th.loc[idx]['dem@GIMP.0715'] - th.loc[idx]['surface@BedMachine'])

    # now using that thickness, put it in a time Series
    dhdt_pix = dhdt_ts.loc[idx]
    dhdt_pix = dhdt_pix - dhdt_pix.loc[t0_pix['day']]
    th_ts.loc[idx] = t0_pix_th + dhdt_pix

th_ts = th_ts[vel.columns]

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
D_gates_fill_weight = pd.DataFrame().reindex_like(D_gates)
for g in D_gates.index:
    g_idx = (DD['gates'] == g)
    D_gates_fill_weight.loc[g] = ((D[g_idx]*fill[g_idx])/D[g_idx].sum()).sum()

D_gates.columns = D_gates.columns.astype(np.str).astype('datetime64[ns]')
D_gates_err.columns = D_gates_err.columns.astype(np.str).astype('datetime64[ns]')
D_gates_fill_weight.columns = D_gates_fill_weight.columns.astype(np.str).astype('datetime64[ns]')
D_gates_fill_weight.clip(lower=0, upper=1, inplace=True)



# D_sector :: Same, but at Mouginot sector scale
# D_sector_err ::
# D_sector_fill ::
D_sectors = DD.groupby('name').sum().drop(['ones','sectors','gates'], axis=1)
D_sectors_err = DD_err.groupby('name').sum().drop(['ones','sectors','gates'], axis=1)
D_sectors_fill_weight = pd.DataFrame().reindex_like(D_sectors)
for s in D_sectors.index:
    s_idx = (DD['name'] == s)
    D_sectors_fill_weight.loc[s] = ((D[s_idx]*fill[s_idx])/D[s_idx].sum()).sum()

D_sectors.columns = D_sectors.columns.astype(np.str).astype('datetime64[ns]')
D_sectors_err.columns = D_sectors_err.columns.astype(np.str).astype('datetime64[ns]')
D_sectors_fill_weight.columns = D_sectors_fill_weight.columns.astype(np.str).astype('datetime64[ns]')
D_sectors_fill_weight.clip(lower=0, upper=1, inplace=True)


# D_region :: Same, but at Mouginot region scale
# D_region_err ::
# D_region_fill ::
D_regions = DD.groupby('regions').sum().drop(['ones','sectors','gates'], axis=1)
D_regions_err = DD_err.groupby('regions').sum().drop(['ones','sectors','gates'], axis=1)
D_regions_fill_weight = pd.DataFrame().reindex_like(D_regions)
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
    
D_regions.columns = D_regions.columns.astype(np.str).astype('datetime64[ns]')
D_regions_err.columns = D_regions_err.columns.astype(np.str).astype('datetime64[ns]')
D_regions_fill_weight.columns = D_regions_fill_weight.columns.astype(np.str).astype('datetime64[ns]')
D_regions_fill_weight.clip(lower=0, upper=1, inplace=True)


# D_all :: Same, but all GIS
# D_all_err ::
# D_all_fill ::
D_all = DD.drop(['regions','sectors','ones','name','gates'], axis=1).sum()
D_all_err = DD_err.drop(['regions','sectors','ones','name','gates'], axis=1).sum()
D_all_fill_weight = pd.Series().reindex_like(D_all)
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
# meta_sector['mean x'] = meta.groupby('sectors').mean()['x'].round().astype(np.int)
# meta_sector['mean y'] = meta.groupby('sectors').mean()['y'].round().astype(np.int)
# meta_sector['n gates'] = meta.groupby('sectors').count()['gates'].round().astype(np.int)
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
# meta_region['n gates'] = meta.groupby('regions').count()['gates'].round().astype(np.int)

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
