from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import time
import os
import sys
import soup_files as sp
import uuid
import threading

THIS_FILE = os.path.realpath(__file__)
THIS_DIR = os.path.dirname(THIS_FILE)
ROOT_DIR_PROJECT = os.path.dirname(THIS_DIR)
DIR_ASSETS = os.path.join(ROOT_DIR_PROJECT, 'assets')
sys.path.insert(0, THIS_DIR)

# Imports Locais
from serverlib.util import (
    BuildAssets, AssetsFrontEnd, ProgressState, CreateProgressState,
    create_temp_dir,
)

load_assets: AssetsFrontEnd = BuildAssets().set_dir_assets(
                                            sp.Directory(DIR_ASSETS).concat('data')
                                        ).build()

create_progress = CreateProgressState()
app = FastAPI()

# ----------------------------------------------------
# 💡 CONFIGURAÇÃO DO CORS
# ----------------------------------------------------
origins = [
    #"*", # Permite todas as origens (MAIS FÁCIL PARA TESTE LOCAL)
    # Se você quiser restringir, use:
    # "http://localhost",
    "http://localhost:5000", # Use a porta real do seu Flutter Web
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos os métodos (GET, POST, etc.)
    allow_headers=["*"],  # Permite todos os cabeçalhos
)

# Variável de estado global para o progresso
# Em uma aplicação de produção, isso estaria em um banco de dados ou serviço de cache (Redis)
progress_state = {"percentage": 0} 


# ----------------------------------------------------
# Funções auxiliares (Mock de processamento)
# ----------------------------------------------------

def update_progress(percentage: int):
    """Atualiza o estado de progresso global."""
    global progress_state
    progress_state["percentage"] = min(100, max(0, percentage))


def mock_processing(id_process: str):
    """Simula o processamento do arquivo e atualiza o progresso."""
    print(f"Iniciando processamento com número Excel")
    progress = create_progress.get_progress(id_process)
    df = pd.read_excel(progress.get_output_bytes())
    columns = df.columns.tolist()
    final = df[df[columns[0]]]
    progress.set_current_value(9)
    output_path = create_temp_dir().join_file('dados.xlsx').absolute()
    final.to_excel(output_path)
    progress.set_output_file(output_path)


#======================================================#
# Rota para receber o arquivo Excel e o número
#======================================================#
@app.post(f"/{load_assets.get_route_process_excel()}")
async def process_excel(
    file: UploadFile = File(...),
    numero: str = Form(...) # Recebido como string, convertido para int no processamento
        ):
    task_id = str(uuid.uuid4())
    progress: ProgressState = create_progress.create_progress(task_id)
    progress.set_total_value(10)
    try:
        # Salva o arquivo temporariamente
        file_bytes = await file.read()
        progress.set_output_bytes(file_bytes)
        progress['number'] = str(numero)
        progress.set_current_value(5)
        
        # O processamento deve ser em uma thread separada para não bloquear
        # a rota de progresso. Aqui, para simplificar, rodaremos sincronicamente,
        # mas *recomenda-se usar BackgroundTasks ou Celery*.
        th = threading.Thread(target=mock_processing, args=(task_id,),)
        th.start()

        return JSONResponse(
            content={
                "message": "Processamento Iniciado",
                "id_process": progress.get_id_process(),
            }
        )

    except Exception as e:
        update_progress(0)
        return JSONResponse(content={"error": str(e)}, status_code=500)
    finally:
        progress.set_current_value(10)
  
        
#======================================================#
# Rota para o frontend buscar o progresso
#======================================================#
@app.get(f"/{load_assets.get_route_progress()}")
def get_progress(id_process: str):
    return JSONResponse(content=create_progress.get_progress(id_process))


#======================================================#
# Rota para download do arquivo processado
#======================================================#
@app.get(f"/{load_assets.get_route_download()}")
async def download_file(id_process: str):
    prog = create_progress.get_progress(id_process)
    file_path = prog.get_output_file()
    if os.path.exists(file_path):
        return FileResponse(
            path=file_path,
            filename=os.path.basename(file_path),
            media_type=prog.get_media_type()
        )
    return JSONResponse(content={"error": "Arquivo não encontrado"}, status_code=404)
