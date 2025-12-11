from serverlib.util.parser_data import ParserData, SearchInData, FilterData
import pandas as pd


class AnalyzeRoteiro(object):

    def __init__(
                self,
                col_uc: str = 'numcdc_csd',
                col_logr: str = 'codlgr',
                col_lv: str = 'numliv_itc',
                col_loc: str = 'codlcd_itc',
                col_rt: str = 'numrota_itc',
            ):
        self.col_uc = col_uc
        self.col_log = col_logr
        self.col_lv = col_lv
        self.col_loc = col_loc
        self.col_rt = col_rt


