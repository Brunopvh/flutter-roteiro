from __future__ import annotations
from collections.abc import Iterator, Hashable
import pandas as pd
from sheet_stream import ListString


class FilterData(object):

    def __init__(self, col_find: str, value_find: str, *, return_cols: list[str] = None):
        self.__col_find = col_find
        self.__value_find = value_find
        if return_cols is None:
            self.__return_cols = []
        else:
            self.__return_cols = return_cols

    def get_col_find(self) -> str:
        return self.__col_find

    def get_value_find(self) -> str:
        return self.__value_find

    def get_return_cols(self) -> list[str]:
        return self.__return_cols

    def set_return_cols(self, return_cols: list[str]):
        self.__return_cols = return_cols


class SearchInData(object):

    def __init__(self, data: pd.DataFrame, filter_data: FilterData):
        self.__data: pd.DataFrame = data.astype('str')
        self.__filter_data: FilterData = filter_data

    def iterrows(self) -> Iterator[tuple[Hashable, pd.Series[str]]]:
        return self.__data.iterrows()

    def get_data(self) -> pd.DataFrame:
        return self.__data

    def get_filter_data(self) -> FilterData:
        return self.__filter_data

    def filter_items(self) -> pd.DataFrame:
        _col_find = self.get_filter_data().get_col_find()
        _value_find = self.get_filter_data().get_value_find()
        final = self.get_data()[self.get_data()[_col_find] == _value_find]
        if len(self.get_filter_data().get_return_cols()) > 0:
            _select = list()
            _select.append(_col_find)
            _select.extend(self.get_filter_data().get_return_cols())
            final = final[_select]
        return final


class ParserData(object):

    def __init__(self, data: pd.DataFrame):
        self.__data: pd.DataFrame = data.astype(str)

    def get_data(self) -> pd.DataFrame:
        return self.__data

    def get_columns(self) -> ListString:
        if self.get_data().empty:
            raise Exception(f"{__class__.__name__} No data available")
        return ListString(self.__data.astype('str').columns.tolist())

    def select_columns(self, columns: list[str]) -> pd.DataFrame:
        if self.get_data().empty:
            raise Exception(f"{__class__.__name__} No data available")
        return self.__data[columns]

    def concat_columns(
                self,
                columns: list[str], *,
                conc_name: str = 'concatenar',
                sep: str = '_'
            ):
        if self.get_data().empty:
            raise Exception(f"{__class__.__name__} No data available")
        self.__data[conc_name] = self.__data[columns].agg(sep.join, axis=1)
