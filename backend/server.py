from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel
import pandas as pd
import time
import os

app = FastAPI()

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

def mock_processing(file_path: str, number_input: int):
    """Simula o processamento do arquivo e atualiza o progresso."""
    update_progress(0)
    print(f"Iniciando processamento com número: {number_input} e arquivo: {file_path}")
    
    # 1. Leitura e início
    update_progress(10)
    time.sleep(1) # Simula leitura
    df = pd.read_excel(file_path)

    # 2. Processamento (Exemplo: adicionar uma coluna)
    update_progress(30)
    time.sleep(2) # Simula processamento pesado
    df['Numero_Digitado'] = number_input

    # 3. Finalização e salvamento
    update_progress(70)
    output_filename = f"processado_{int(time.time())}.xlsx"
    output_path = os.path.join("/tmp", output_filename) 
    df.to_excel(output_path, index=False)
    
    update_progress(100)
    time.sleep(0.5) # Garantir que o 100% seja visto
    
    return output_path

### 2. Rotas do FastAPI

#### Rota 1: `POST /api/processar`

# Rota para receber o arquivo Excel e o número
@app.post("/api/processar")
async def process_excel(
    file: UploadFile = File(...), 
    numero: str = Form(...) # Recebido como string, convertido para int no processamento
):
    try:
        # Salva o arquivo temporariamente
        temp_file_path = f"/tmp/{file.filename}"
        with open(temp_file_path, "wb") as buffer:
            buffer.write(await file.read())

        # Inicia o processamento
        update_progress(5)
        
        # O processamento deve ser em uma thread separada para não bloquear
        # a rota de progresso. Aqui, para simplificar, rodaremos sincronicamente,
        # mas *recomenda-se usar BackgroundTasks ou Celery*.
        output_file_path = mock_processing(temp_file_path, int(numero))
        
        # Limpeza do arquivo temporário de entrada
        os.remove(temp_file_path)

        return JSONResponse(content={"message": "Processamento concluído", "download_path": os.path.basename(output_file_path)})

    except Exception as e:
        update_progress(0)
        return JSONResponse(content={"error": str(e)}, status_code=500)
    finally:
        # Zera o progresso após o processamento/erro
        time.sleep(1)
        update_progress(0)
        
        
# Rota para o frontend buscar o progresso
@app.get("/api/progresso")
def get_progress():
    return JSONResponse(content=progress_state)


# Rota para download do arquivo processado
@app.get("/api/download/{filename}")
async def download_file(filename: str):
    file_path = os.path.join("/tmp", filename)
    if os.path.exists(file_path):
        return FileResponse(
            path=file_path,
            filename=filename,
            media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        )
    return JSONResponse(content={"error": "Arquivo não encontrado"}, status_code=404)