from __future__ import annotations

from typing import Any
from sheet_stream import ListItems, ListString


class ProgressState(dict[str, Any]):

    def __init__(self, values: dict[str, Any] = None):
        if values is None:
            super().__init__({})
        else:
            super().__init__(values)

        self['name_process'] = None
        self['total'] = 0
        self['current'] = 0
        self['id_process'] = -1
        self['output_file'] = None
        self['output_bytes'] = None
        self['active'] = False
        self['message'] = None
        self['done'] = False
        self['media_type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

    def __hash__(self):
        return self.get_id_process()

    def __eq__(self, other):
        return self.get_id_process() == other.get_id_process()

    def get_media_type(self) -> str:
        return self['media_type']

    def set_media_type(self, media_type: str):
        self['media_type'] = media_type

    def iqual(self, other: ProgressState) -> bool:
        return self.__eq__(other)

    def get_message(self) -> str | None:
        return self['message']

    def set_message(self, msg: str):
        self['message'] = msg

    def id_done(self) -> bool:
        return self['done']

    def set_done(self, done: bool):
        self['done'] = done

    def set_status(self, status: bool):
        self['active'] = status

    def get_status(self) -> bool:
        return self['active']

    def get_name_process(self) -> str | None:
        return self['name_process']

    def set_name_process(self, name: str):
        self['name_process'] = name

    def get_output_bytes(self) -> bytes | None:
        return self['output_bytes']

    def set_output_bytes(self, out: bytes) -> None:
        self['output_bytes'] = out

    def get_output_file(self) -> str | None:
        return self['output_file']

    def set_output_file(self, file: str) -> None:
        self['output_file'] = file

    def get_total_value(self) -> int:
        return self['total']

    def set_total_value(self, total: int):
        self['total'] = total

    def get_id_process(self) -> int:
        return self['id_process']

    def set_id_process(self, id_process: int):
        self['id_process'] = id_process

    def get_current_value(self) -> int:
        return self['current']

    def set_current_value(self, current: int):
        self['current'] = current


class CreateProgressState(dict[str, Any]):

    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(CreateProgressState, cls).__new__(cls)
        return cls._instance

    def __init__(self):
        super().__init__({})
        if not hasattr(self, '_initialized'):
            self._initialized = True
        if self._initialized:
            return

    def keys(self) -> ListString:
        return ListString(list(super().keys()))

    def create_progress(self, id_process: str) -> ProgressState:
        if not id_process in self:
            self[id_process] = ProgressState()
        return self[id_process]

    def contains_progress(self, id_progress: str) -> bool:
        return id_progress in self

    def get_progress(self, id_progress: str) -> ProgressState:
        try:
            return self.get(id_progress)
        except Exception as e:
            print(f'{__class__.__name__} {e}')









