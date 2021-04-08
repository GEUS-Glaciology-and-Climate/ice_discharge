import matplotlib.gridspec as gridspec
import numpy as np
import pandas as pd
from adjust_spines import adjust_spines as adj
import matplotlib.pyplot as plt
import datetime as dt

plt.close(1)

fig = plt.figure(1, figsize=(9,5)) # w,h
fig.clf()
grid = plt.GridSpec(2, 1, height_ratios=[1,5], hspace=0.1) # h, w

ax_D = fig.add_subplot(grid[1,:])
ax_coverage = fig.add_subplot(grid[0,:], sharex=ax_D)

adj(ax_D, ['left','bottom'])
adj(ax_coverage, ['left'])
ax_coverage.minorticks_off()
ax_coverage.tick_params(length=0, which='both', axis='x')

D = pd.read_csv("./out/GIS_D.csv", index_col=0, parse_dates=True)
err = pd.read_csv("./out/GIS_err.csv", index_col=0, parse_dates=True)
coverage = pd.read_csv("./out/GIS_coverage.csv", index_col=0, parse_dates=True)

THRESH = coverage.values.flatten() < 0.5
D[THRESH] = np.nan
err[THRESH] = np.nan
coverage[THRESH] = np.nan

# Add t0 and t_end so that graph covers a nice time span
def pad_df(df):
    df = df.append(pd.DataFrame(index=np.array(['1986-01-01']).astype('datetime64[ns]')), sort=True)
    idx = str(df.index.year.max())+'-12-31'
    df = df.append(pd.DataFrame(index=np.array([idx]).astype('datetime64[ns]')), sort=True)
    df = df.sort_index()
    return df

D = pad_df(D)
err = pad_df(err)
coverage = pad_df(coverage)

MS=4
ax_D.errorbar(err.index, D.values, fmt='o', mfc='none', mec='k', ms=MS)
for i in np.arange(D.values.size):
    ax_D.errorbar(D.index[i], D.values[i],
                  yerr=err.values[i], ecolor='grey',
                  alpha=coverage.values[i][0],
                  marker='o', ms=MS, mfc='k', mec='k')

# Take annual average from daily interpolated rather than the existing samples.
D_day_year = D.resample('1D').mean().interpolate(method='time',limit_area='inside',axis=0).resample('A').mean()
err_day_year = err.resample('1D').mean().interpolate(method='time',limit_area='inside',axis=0).resample('A').mean()

# No annual average if few sample
num_obs = D.resample('Y').count().values
D_day_year[num_obs < 4] = np.nan
err_day_year[num_obs < 4] = np.nan

Z=99
D_day_year.plot(drawstyle='steps', linewidth=3, ax=ax_D, alpha=0.75, color='orange', zorder=Z)

ax_D.legend("", framealpha=0)
ax_D.set_xlabel('Time [Years]')
ax_D.set_ylabel('Discharge [Gt yr$^{-1}$]')

import matplotlib.dates as mdates
ax_D.xaxis.set_major_locator(mdates.YearLocator())
ax_D.minorticks_off()
ax_D.xaxis.set_tick_params(rotation=-90) #, ha="left", rotation_mode="anchor")
for tick in ax_D.xaxis.get_majorticklabels():
    tick.set_horizontalalignment("left")

ax_D.set_xlim(D.index[0], D.index[-1])

###
### Coverage
###

ax_coverage.scatter(coverage.index, coverage.values*100,
                    color='k',
                    marker='.',
                    alpha=0.25)
                  # linewidth=3,
ax_coverage.set_ylim(45,105)
ax_coverage.set_yticks([50,100])
ax_coverage.spines['left'].set_bounds(ax_coverage.get_ylim()[0],100)
ax_coverage.set_ylabel('Coverage [%]')

plt.savefig('./figs/discharge_ts.png', transparent=False, bbox_inches='tight', dpi=300)

disp = pd.DataFrame(index = D_day_year.index.year,
                    data = {'D' : D_day_year.values.flatten(), 
                            'err' : err_day_year.values.flatten()})
disp.index.name = 'Year'
disp

import matplotlib.gridspec as gridspec
import numpy as np
import pandas as pd
from adjust_spines import adjust_spines as adj
import datetime as dt

plt.close(1)

fig = plt.figure(1, figsize=(9,7)) # w,h
fig.clf()
# fig.set_tight_layout(True)
grid = plt.GridSpec(2, 1, height_ratios=[1,6], hspace=0.1) # h, w

ax_D = fig.add_subplot(grid[1,:])
ax_coverage = fig.add_subplot(grid[0,:], sharex=ax_D)

from adjust_spines import adjust_spines as adj
adj(ax_D, ['left','bottom'])
adj(ax_coverage, ['left'])
ax_coverage.minorticks_off()
ax_coverage.tick_params(length=0, which='both', axis='x')


D = pd.read_csv("./out/region_D.csv", index_col=0, parse_dates=True)
err = pd.read_csv("./out/region_err.csv", index_col=0, parse_dates=True)
coverage = pd.read_csv("./out/region_coverage.csv", index_col=0, parse_dates=True)

THRESH = coverage < 0.5
D[THRESH] = np.nan
err[THRESH] = np.nan
coverage[THRESH] = np.nan

def pad_df(df):
    df = df.append(pd.DataFrame(index=np.array(['1986-01-01']).astype('datetime64[ns]')), sort=True)
    idx = str(df.index.year.max())+'-12-31'
    df = df.append(pd.DataFrame(index=np.array([idx]).astype('datetime64[ns]')), sort=True)
    df = df.sort_index()
    return df

D = pad_df(D)
err = pad_df(err)
coverage = pad_df(coverage)

### Take annual average from daily interpolated rather than the existing samples.
D_day_year = D.resample('1D',axis='rows').mean().interpolate(method='time',limit_area='inside').resample('A',axis='rows').mean()
err_day_year=err.resample('1D',axis='rows').mean().interpolate(method='time',limit_area='inside').resample('A',axis='rows').mean()

# No annual average if few sample
num_obs = D.resample('Y').count().values
D_day_year[num_obs<=3] = np.nan
err_day_year[num_obs<=3] = np.nan

MS=4
Z=99
for r in D.columns:
    e = ax_D.errorbar(D[r].index, D[r].values, fmt='o', mfc='none', ms=MS)
    C = e.lines[0].get_color()
    D_day_year[r].plot(drawstyle='steps', linewidth=2, ax=ax_D,
                       color=C,
                       # color='orange'
                       alpha=0.75, zorder=Z)
    for i in np.arange(D.index.size):
        ax_D.errorbar(D.iloc[i].name, D.iloc[i][r],
                      yerr=err.iloc[i][r], ecolor='gray',
                      marker='o', ms=MS,
                      # mfc='k', mec='k',
                      mfc=C, mec=C,
                      alpha=coverage.iloc[i][r])

    tx = pd.Timestamp(str(D[r].dropna().index[-1].year) + '-01-01') + dt.timedelta(days=380)
    ty = D_day_year[r].dropna().iloc[-1]
    # if r in ['CE', 'SW']: ty=ty-4
    # if r == 'NE': ty=ty+4
    # if r == 'NO': ty=ty-2
    ax_D.text(tx, ty, r, verticalalignment='center', horizontalalignment='left')

    # if r in ['CE','NE','SE']:
    ax_coverage.scatter(coverage.index, coverage[r]*100,
                        marker='.',
                        alpha=0.25,
                        color=C)

ax_coverage.set_ylabel('Coverage [%]')
ax_coverage.set_ylim(45,105)
ax_coverage.set_yticks([50,100])
ax_coverage.spines['left'].set_bounds(ax_coverage.get_ylim()[0],100)
    
import matplotlib.dates as mdates
ax_D.xaxis.set_major_locator(mdates.YearLocator())

# plt.legend()
ax_D.legend("", framealpha=0)
ax_D.set_xlabel('Time [Years]')
ax_D.set_ylabel('Discharge [Gt yr$^{-1}$]')
ax_D.set_xlim(D.index[0], D.index[-1])
ax_D.set_xticklabels(D.index.year.unique())
# ax_D.set_yscale('log')

ax_D.xaxis.set_tick_params(rotation=-90)
for tick in ax_D.xaxis.get_majorticklabels():
    tick.set_horizontalalignment("left")

plt.savefig('./figs/discharge_ts_regions.png', transparent=False, bbox_inches='tight', dpi=300)
# plt.savefig('./figs/discharge_ts_regions.pdf', transparent=True, bbox_inches='tight', dpi=300)

Err_pct = (err_day_year.values/D_day_year.values*100).round().astype(np.int).astype(np.str)
Err_pct[Err_pct.astype(np.float)<0] = 'NaN'
tbl = (D_day_year.round().fillna(value=0).astype(np.int).astype(np.str) + ' ('+Err_pct+')')
tbl.index = tbl.index.year.astype(np.str)
tbl.columns = [_ + ' (Err %)' for _ in tbl.columns]
tbl

import matplotlib.gridspec as gridspec
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

plt.close(1)

fig = plt.figure(1, figsize=(9,5)) # w,h
fig.clf()
# fig.set_tight_layout(True)
grid = plt.GridSpec(2, 1, height_ratios=[1,10], hspace=0.1) # h, w


ax_D = fig.add_subplot(grid[1,:])
ax_coverage = fig.add_subplot(grid[0,:], sharex=ax_D)

from adjust_spines import adjust_spines as adj
adj(ax_D, ['left','bottom'])
adj(ax_coverage, ['left'])
ax_coverage.minorticks_off()
ax_coverage.tick_params(length=0, which='both', axis='x')


D = pd.read_csv("./out/sector_D.csv", index_col=0, parse_dates=True)
err = pd.read_csv("./out/sector_err.csv", index_col=0, parse_dates=True)
coverage = pd.read_csv("./out/sector_coverage.csv", index_col=0, parse_dates=True)

THRESH = coverage < 0.5
D[THRESH] = np.nan
err[THRESH] = np.nan
coverage[THRESH] = np.nan


def pad_df(df):
    df = df.append(pd.DataFrame(index=np.array(['1986-01-01']).astype('datetime64[ns]')), sort=True)
    idx = str(df.index.year.max())+'-12-31'
    df = df.append(pd.DataFrame(index=np.array([idx]).astype('datetime64[ns]')), sort=True)
    df = df.sort_index()
    return df

D = pad_df(D)
err = pad_df(err)
coverage = pad_df(coverage)

### Take annual average from daily interpolated rather than the existing samples.
D_day_year = D.resample('1D',axis='rows').mean().interpolate(method='time',limit_area='inside').resample('A',axis='rows').mean()
err_day_year=err.resample('1D',axis='rows').mean().interpolate(method='time',limit_area='inside').resample('A',axis='rows').mean()


# No annual average if few sample
num_obs = D.resample('Y').count()
D_day_year[num_obs<=3] = np.nan
err_day_year[num_obs<=3] = np.nan


# largest average for last year
D_sort = D.resample('Y', axis='rows')\
          .mean()\
          .iloc[-1]\
          .sort_values(ascending=False)

LABELS={}
# for k in D_sort.head(8).index: LABELS[k] = k
# Use the last       ^ glaciers

# Make legend pretty
LABELS['JAKOBSHAVN_ISBRAE'] = 'Sermeq Kujalleq (Jakobshavn Isbræ)'
LABELS['HELHEIMGLETSCHER'] = 'Helheim Gletsjer'
LABELS['KANGERLUSSUAQ'] = 'Kangerlussuaq Gletsjer'
LABELS['KOGE_BUGT_C'] = '(Køge Bugt C)'
LABELS['ZACHARIAE_ISSTROM'] = 'Zachariae Isstrøm'
LABELS['RINK_ISBRAE'] = 'Kangilliup Sermia (Rink Isbræ)'
LABELS['NIOGHALVFJERDSFJORDEN'] = '(Nioghalvfjerdsbrae)'
LABELS['PETERMANN_GLETSCHER'] ='Petermann Gletsjer'

SYMBOLS={}
SYMBOLS['JAKOBSHAVN_ISBRAE'] = 'o'
SYMBOLS['HELHEIMGLETSCHER'] = 's'
SYMBOLS['KANGERLUSSUAQ'] = 'v'
SYMBOLS['KOGE_BUGT_C'] = '^'
SYMBOLS['NIOGHALVFJERDSFJORDEN'] = 'v'
SYMBOLS['RINK_ISBRAE'] = 's'
SYMBOLS['ZACHARIAE_ISSTROM'] = 'o'
SYMBOLS['PETERMANN_GLETSCHER'] ='^'

MS=4
Z=99
for g in LABELS.keys(): # for each glacier

    # scatter of symbols
    e = ax_D.errorbar(D.loc[:,g].index,
                      D.loc[:,g].values,
                      label=LABELS[g],
                      fmt=SYMBOLS[g],
                      mfc='none',
                      ms=MS)

    # Annual average
    C = e.lines[0].get_color()
    D_day_year.loc[:,g].plot(drawstyle='steps', linewidth=2,
                             label='',
                             ax=ax_D,
                             alpha=0.75, color=C, zorder=Z)

    # Error bars, each one w/ custom opacity.
    # Also, fill symbols w/ same opacity.
    for i,idx in enumerate(D.loc[:,g].index):
        ax_D.errorbar(D.loc[:,g].index[i],
                      D.loc[:,g].values[i],
                      yerr=err.loc[:,g].values[i],
                      alpha=coverage.loc[:,g].values[i],
                      label='',
                      marker=SYMBOLS[g],
                      ecolor='grey',
                      mfc=C, mec=C,
                      ms=MS)


    # Coverage scatter on top axis
    ax_coverage.scatter(D.loc[:,g].index,
                        coverage.loc[:,g].values*100,
                        alpha=0.25,
                        marker=SYMBOLS[g],
                        facecolor='none',
                        s=10,
                        color=C)

# yl = ax_D.get_ylim()

ax_D.legend(fontsize=8, ncol=2, loc=(0.0, 0.82), fancybox=False, frameon=False)
ax_D.set_xlabel('Time [Years]')
ax_D.set_ylabel('Discharge [Gt yr$^{-1}$]')
ax_D.set_xlim(D.index[0], D.index[-1])
ax_D.set_xticklabels(D.index.year.unique())

import matplotlib.dates as mdates
ax_D.xaxis.set_major_locator(mdates.YearLocator())
ax_D.xaxis.set_tick_params(rotation=-90)
for tick in ax_D.xaxis.get_majorticklabels():
    tick.set_horizontalalignment("left")

ax_coverage.set_ylabel('Coverage [%]')
ax_coverage.set_ylim([45,105])
ax_coverage.set_yticks([50,100])
ax_coverage.spines['left'].set_bounds(ax_coverage.get_ylim()[0],100)

plt.savefig('./figs/discharge_ts_topfew.png', transparent=False, bbox_inches='tight', dpi=300)

Err_pct = (err_day_year / D_day_year*100).round().fillna(value=0).astype(np.int).astype(np.str)
Err_pct = Err_pct[list(LABELS.keys())]
tbl = D_day_year[list(LABELS.keys())].round().fillna(value=0).astype(np.int).astype(np.str) + ' (' + Err_pct+')'
tbl.index = tbl.index.year.fillna(value=0).astype(np.str)
tbl.columns = [_ + ' (%)' for _ in tbl.columns]
tbl
