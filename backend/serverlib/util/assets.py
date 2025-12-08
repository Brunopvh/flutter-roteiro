from __future__ import annotations
import tempfile
from typing import Any
import soup_files as sp

FILE_PATH_ASSETS: sp.File = None


def create_temp_dir() -> sp.Directory:
    # Criar diretório temporário para saída
    return sp.Directory(tempfile.mkdtemp())


class AssetsFrontEnd(dict[str, Any]):

    _instance = None

    def __new__(cls, *args, **kwargs):
        # Verifica se a instância já existe
        if cls._instance is None:
            cls._instance = super(AssetsFrontEnd, cls).__new__(cls)
        return cls._instance

    def __init__(self, **kwargs) -> None:
        super().__init__({})

        if not hasattr(self, '_initialized'):
            print('Asset Iniciado')
            self._initialized = True  # Marca como inicializado
            self.kwargs: dict = kwargs
            self['ip_server'] = None
            self.__dir_assets: sp.Directory = None
            self.__dict_asset = None

    def get_dir_assets(self) -> sp.Directory:
        return self.__dir_assets

    def set_dir_assets(self, new: sp.Directory):
        if new is not None:
            self.__dir_assets = new

    def get_file_json_assets(self) -> sp.File:
        if self.get_dir_assets() is None:
            raise ValueError(f'{__class__.__name__} Diretório assets é None')
        return self.get_dir_assets().join_file('ips.json')

    def get_dict_assets(self) -> dict[str, str]:
        if self.__dict_asset is None:
            data: sp.JsonData = sp.JsonConvert.from_file(self.get_file_json_assets()).to_json_data()
            self.__dict_assets = data.to_dict()
        return self.__dict_assets

    def get_ip_server(self) -> str:
        if self['ip_server'] is None:
            self['ip_server'] = self.get_dict_assets()['ip_server']
        return self['ip_server']

    def get_route_process_excel(self) -> str:
        return self.get_dict_assets()['rt_process_excel']

    def get_route_progress(self) -> str:
        return self.get_dict_assets()['rt_progress']

    def get_route_download(self) -> str:
        return self.get_dict_assets()['rt_download']


class BuildAssets(object):
    asset_dir: sp.Directory = None

    def __init__(self) -> None:
        self._DIR_ASSETS = None

    def set_dir_assets(self, d: sp.Directory) -> BuildAssets:
        if d is not None:
            self._DIR_ASSETS = d
        return self

    def build(self) -> AssetsFrontEnd:
        if self._DIR_ASSETS is None:
            raise ValueError('Diretório assets é None!!!')
        _asset = AssetsFrontEnd()
        _asset.set_dir_assets(self._DIR_ASSETS)
        return _asset
