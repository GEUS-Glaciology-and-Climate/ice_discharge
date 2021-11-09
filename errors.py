from uncertainties import unumpy
import pandas as pd
import numpy as np

df = pd.read_csv("./tmp/dat_100_5000.csv")

err_sector = pd.DataFrame(columns=['D', 'E', 'E%'])
err_sector.index.name = 'Sector'

sectors = np.unique(df['sectors@Mouginot_2019'].values)
for s in sectors:
    sub_s = df[df['sectors@Mouginot_2019'] == s]
    thick = sub_s['thickness@BedMachine']
    # vel = sub_s['vel_baseline@MEaSUREs.0478']
    vel = np.abs(sub_s['vx_baseline@MEaSUREs.0478']*sub_s['gates_x@gates_100_5000']) + np.abs(sub_s['vy_baseline@MEaSUREs.0478']*sub_s['gates_y@gates_100_5000'])
    D = 200  * thick * vel * 917 / 1E12
    err_thick = np.abs(sub_s['errbed@BedMachine'].values)
    # err_thick[np.where(err_thick < 50)] = 50  # IS THIS REASONABLE? IMPORTANT?
    e_th = 200 * err_thick * vel * 917 / 1E12
    err_sector.loc[s] = [np.sum(D), np.sum(e_th), np.round(np.sum(e_th),10)/np.round(np.sum(D),10)*100]

err_sector.loc['GIS'] = np.sum(err_sector, axis=0)
err_sector.loc['GIS']['E%'] = err_sector.loc['GIS']['E']/err_sector.loc['GIS']['D']*100

err_sector.to_csv('./tmp/err_sector_mouginot.csv')

err_sector.rename(columns = {'D':'D [Gt]',
                             'E':'Error [Gt]',
                             'E%':'Error [%]'}, inplace=True)

err_sector

from uncertainties import unumpy
import pandas as pd
import numpy as np

df = pd.read_csv("./tmp/dat_100_5000.csv")

err_region = pd.DataFrame(columns=['D','E', 'E%'])
err_region.index.name = 'Region'

regions = np.unique(df['regions@Mouginot_2019'].values)
for r in regions:
   sub_r = df[df['regions@Mouginot_2019'] == r]
   thick = sub_r['thickness@BedMachine']
   vel = np.abs(sub_r['vx_baseline@MEaSUREs.0478']*sub_r['gates_x@gates_100_5000']) + np.abs(sub_r['vy_baseline@MEaSUREs.0478']*sub_r['gates_y@gates_100_5000'])
   D = 200  * thick * vel * 917 / 1E12
   err_thick = np.abs(sub_r['errbed@BedMachine'].values)
   # err_thick[np.where(err_thick < 50)] = 50  # IS THIS REASONABLE? IMPORTANT?
   e_th = 200 * err_thick * vel * 917 / 1E12
   err_region.loc[r] = [np.sum(D), np.sum(e_th), np.round(np.sum(e_th),10)/np.round(np.sum(D),10)*100]

err_region.loc['GIS'] = np.sum(err_region, axis=0)
err_region.loc['GIS']['E%'] = err_region.loc['GIS']['E']/err_region.loc['GIS']['D']*100

err_region.to_csv('./tmp/err_region_mouginot.csv')

err_region.rename(columns = {'D':'D [Gt]', 
                         'E':'Error [Gt]',
                         'E%':'Error [%]'}, inplace=True)

err_region

from uncertainties import unumpy
import pandas as pd
import numpy as np

df = pd.read_csv("./tmp/dat_100_5000.csv")

err_gate = pd.DataFrame(columns=['D','E', 'E%'])
err_gate.index.name = 'Gate'

gates = np.unique(df['gates_gateID@gates_100_5000'].values)
for g in gates:
    sub = df[df['gates_gateID@gates_100_5000'] == g]
    thick = sub['thickness@BedMachine']
    vel = np.abs(sub['vx_baseline@MEaSUREs.0478'])*sub['gates_x@gates_100_5000'] + np.abs(sub['vy_baseline@MEaSUREs.0478'])*sub['gates_y@gates_100_5000']
    D = 200  * thick * vel * 917 / 1E12
    err_thick = np.abs(sub['errbed@BedMachine'].values)
    # err_thick[np.where(err_thick < 50)] = 50  # IS THIS REASONABLE? IMPORTANT?
    e_th = 200 * err_thick * vel * 917 / 1E12
    err_gate.loc[g] = [np.sum(D), np.sum(e_th), np.sum(e_th)/np.sum(D)*100]

err_gate.loc['GIS'] = np.sum(err_gate, axis=0)
err_gate.loc['GIS']['E%'] = err_gate.loc['GIS']['E']/err_gate.loc['GIS']['D']*100

gate_meta = pd.read_csv("./out/gate_meta.csv")
err_gate['name'] = ''
for g in err_gate.index.values:
    if (g == 'GIS'): continue
    if (sum(gate_meta.gate == g) == 0): continue
    err_gate.loc[g,'name'] = gate_meta[gate_meta.gate == g].Mouginot_2019.values[0]

err_gate.to_csv('./tmp/err_gate.csv')
err_gate.rename(columns = {'D':'D [Gt]', 
                           'E':'Error [Gt]',
                           'E%':'Error [%]'}, inplace=True),

err_gate
