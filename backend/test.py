import os
import sys
import soup_files as sp

THIS_FILE = os.path.realpath(__file__)
THIS_DIR = os.path.dirname(THIS_FILE)
ROOT_DIR_PROJECT = os.path.dirname(THIS_DIR)
DIR_ASSETS = os.path.join(ROOT_DIR_PROJECT, 'assets')
sys.path.insert(0, THIS_DIR)

# Imports Locais
from serverlib.util import (
    BuildAssets, AssetsFrontEnd, ProgressState, CreateProgressState,
    create_temp_dir
)
from serverlib.util.parser_data import ParserData, SearchInData, FilterData
import pandas as pd

f = '/home/brunoc/Downloads/Rotas/2023-11 ROL PVH.xlsx'
out = '/home/brunoc/Downloads/Rotas/filtro.xlsx'

df = pd.read_excel(f)
fil = FilterData('LIVRO', '5', return_cols=['CONC', 'UC'])
fd = SearchInData(df, fil)

data = fd.filter_items()
data.to_excel(out, index=False)

