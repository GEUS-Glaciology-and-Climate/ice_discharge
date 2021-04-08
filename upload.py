from pyDataverse.api import NativeApi
import os
import json

import subprocess
hash = subprocess.check_output(["git", "describe", "--always"]).strip().decode('utf-8')
hash = subprocess.check_output(["git", "describe", "--always", "--dirty='*'"]).strip().decode('utf-8')
assert("*" not in hash)

base_url = 'https://dataverse01.geus.dk/'
api_token = 'nnnnnnnnnnnnnnnnnnnnnnnnnnn'


api = NativeApi(base_url, api_token) # establish connection

# get dataverse metadata
identifier = 'doi:10.22008/promice/data/ice_discharge/d/v02'
resp = api.get_dataset(identifier)
files = resp.json()['data']['latestVersion']['files']
for f in files:
    persistentId = f['dataFile']['persistentId']
    description = f['dataFile']['description']
    filename = f['dataFile']['filename']
    fileId = f['dataFile']['id']

    assert(os.path.isfile("./out/"+filename))

    description = description.split(".")[0] + ". "
    description = description + "Git hash: " + hash
    
    if 'content' in locals(): del(content)
    if filename[-3:] == ".nc": content = "application/x-netcdf"
    if filename[-3:] == "csv": content = "text/csv"
    if filename[-3:] == "txt": content = "text/plain"
    json_dict={"description":description, 
               "directoryLabel":".", 
               "forceReplace":True, 
               "filename":filename, 
               "label":filename, 
               "contentType":content}

    json_str = json.dumps(json_dict)
    d = api.replace_datafile(persistentId, "./out/"+filename, json_str)
  
    if d.json()["status"] == "ERROR": 
        print(d.content)
        print("\n")
        continue

    # need to update filenames after uploading because of DataVerse bug
    # https://github.com/IQSS/dataverse/issues/7223
    file_id = d.json()['data']['files'][0]['dataFile']['id']
    d2 = api.update_datafile_metadata(file_id, json_str=json_str, is_filepid=False)
