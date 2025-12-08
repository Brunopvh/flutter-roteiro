// lib/pages/home_page.dart (ou o nome do seu arquivo)

import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio; // Usa Dio com alias
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Para checar a plataforma
import 'package:rotas/util/load_assets.dart'; // Certifique-se de que o caminho está correto

// ----------------------------------------------------
// ProcessamentoPage (Corrigido e Otimizado)
// ----------------------------------------------------

class ProcessamentoPage extends StatefulWidget {
  const ProcessamentoPage({super.key});

  @override
  State<ProcessamentoPage> createState() => _ProcessamentoPageState();
}

class _ProcessamentoPageState extends State<ProcessamentoPage> {
  final TextEditingController _numberController = TextEditingController();
  final dio.Dio _dio = dio.Dio();

  // NOVO ESTADO: Armazena o PlatformFile inteiro (com bytes na Web).
  PlatformFile? _xlsxFile; 
  String? _selectedFileName; // Apenas para exibição na UI

  double _progress = 0.0;
  Timer? _progressTimer;
  bool _isProcessing = false;
  String? _idProcess;

  final LoadAssets loadFileAsset = LoadAssets.create();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _numberController.dispose();
    super.dispose();
  }

  // 💡 MÉTODOS ASYNC DE LEITURA DO ASSET
  Future<String> getUrlServer() async {
    return await this.getIpValue('ip_server');
  }

  Future<String> getIpValue(String key) async {
    // 💡 Usa Map<String, String> corrigido do LoadAssets
    final Map<String, String> data = await this.loadFileAsset.getJsonIps();
    return data[key] ?? '';
  }

  // ----------------------------------------------------
  // Lógica de Seleção de Arquivo (ARROMEDANENTO) 📁
  // ----------------------------------------------------
  Future<void> _selectFile() async {
    // Carrega os bytes APENAS se for Web, para garantir upload posterior.
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: kIsWeb, 
    );

    if (result != null) {
      final file = result.files.single;

      // Validação básica para Web
      if (kIsWeb && file.bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Erro: Arquivo Web não contém dados.')),
          );
          return;
      }
      
      setState(() {
          _xlsxFile = file; // <-- ARMAZENA O PlatformFile
          _selectedFileName = file.name;
      });

    }
  }

  // Auxiliar para obter o MultipartFile (USA O ESTADO) 💾
  // NÃO CHAMA MAIS o FilePicker.
  Future<dio.MultipartFile> _getFileData() async {
    if (_xlsxFile == null) {
        throw Exception("Nenhum arquivo XLSX selecionado para upload.");
    }
    
    final file = _xlsxFile!;
    
    if (kIsWeb) {
        // Web: Usa os bytes armazenados
        if (file.bytes == null) {
            throw Exception("Erro: Dados do arquivo não estão disponíveis (Web).");
        }
        return dio.MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
        );
    } else {
        // Mobile/Desktop: Usa o path
        if (file.path == null) {
            throw Exception("Erro: Caminho do arquivo não está disponível (Mobile/Desktop).");
        }
        return await dio.MultipartFile.fromFile(
            file.path!,
            filename: file.name,
        );
    }
  }


  // ----------------------------------------------------
  // Lógica de Polling de Progresso (INALTERADA)
  // ----------------------------------------------------

  /// Controla o início e o fim da atualização da barra de progresso via polling.
  void controlProgressPolling(bool startPolling, String urlServer, String taskId) {
    if (startPolling) {
      setState(() {
        _progress = 0.0;
        _isProcessing = true;
        _idProcess = taskId;
      });

      _progressTimer?.cancel();

      _progressTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        timer,
      ) async {
        try {
          String rtProg = await this.loadFileAsset.getRouteProgress();

          final response = await _dio.get(
            '$urlServer/$rtProg',
            queryParameters: {'id_process': taskId},
          );

          if (mounted) {
            final newProgress = (response.data['percentage'] as num).toDouble() / 100.0;

            setState(() {
              _progress = newProgress;
            });

            if (newProgress >= 1.0) {
              _stopProgressPolling();
              setState(() {
                _isProcessing = false;
              });
            }
          }
        } catch (e) {
          print('Erro ao buscar progresso: $e');
          _stopProgressPolling();
          setState(() {
            _isProcessing = false;
            _progress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao monitorar progresso: $e')),
          );
        }
      });
    } else {
      _stopProgressPolling();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _stopProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // ----------------------------------------------------
  // Lógica de Processamento e Download
  // ----------------------------------------------------

  Future<void> processSheet() async {
    // 💡 Validação do arquivo: Checa se o objeto PlatformFile existe
    if (_xlsxFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um arquivo Excel para prosseguir.'),
        ),
      );
      return;
    }

    if (_numberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um número para prosseguir.'),
        ),
      );
      return;
    }

    if (_isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operação em andamento, aguarde.'),
        ),
      );
      return;
    }

    final String serverUrl = await this.getUrlServer();
    final String rtProcess = await this.loadFileAsset.getRouteProcessExcel();

    if (serverUrl.isEmpty || rtProcess.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Configuração de IP ou Rota de Processamento ausente.')),
        );
        return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
    });

    try {
      final dio.MultipartFile fileData = await this._getFileData(); // Obtém do estado
      final dio.FormData formData = dio.FormData.fromMap({
        'numero': _numberController.text,
        'file': fileData,
      });

      final response = await _dio.post(
        '$serverUrl/$rtProcess',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['id_process'] != null) {
        final String taskId = response.data['id_process'];
        this.controlProgressPolling(true, serverUrl, taskId);

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Processamento iniciado. ID: $taskId')),
        );

      } else {
        this.controlProgressPolling(false, serverUrl, '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro no processamento: ${response.data['error'] ?? 'Desconhecido'}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Erro no processamento/conexão: $e');
      this.controlProgressPolling(false, serverUrl, '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha na comunicação com o servidor: $e')),
      );
    }
  }

  Future<void> _downloadFile() async {
    if (_idProcess == null || _progress < 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde o processamento ser concluído (100%).')),
      );
      return;
    }

    try {
      final String serverUrl = await this.getUrlServer();
      final String rtDownload = await this.loadFileAsset.getRouteDownload();

      if (serverUrl.isEmpty || rtDownload.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Configuração de IP ou Rota de Download ausente.')),
        );
        return;
      }

      final downloadUrl = '$serverUrl/$rtDownload?id_process=$_idProcess';

      final anchor = html.AnchorElement(href: downloadUrl)
        ..setAttribute("download", 'processado_$_idProcess.xlsx')
        ..click();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download iniciado!')),
      );

    } catch (e) {
      print('Erro no download: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao iniciar o download.')),
      );
    }
  }

  // ----------------------------------------------------
  // Interface do Usuário (UI)
  // ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isDownloadReady = _progress >= 1.0 && !_isProcessing && _idProcess != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Processador Excel - Flutter/FastAPI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Barra de Progresso
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[300],
                color: _isProcessing
                    ? Colors.blue
                    : (isDownloadReady ? Colors.green : Colors.grey),
              ),
              const SizedBox(height: 24),
              Text(
                'Progresso: ${(_progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // 2. Botão para Selecionar Excel
              ElevatedButton.icon(
                onPressed: _selectFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _selectedFileName ?? 'Selecionar Planilha Excel (.xlsx)',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Caixa de Texto
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Digite um Número',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 32),

              // 4. Botão Processar
              ElevatedButton.icon(
                // Desabilita se estiver processando ou pronto para download
                onPressed: _isProcessing || isDownloadReady ? null : processSheet, 
                icon: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isProcessing ? 'PROCESSANDO...' : 'PROCESSAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              // 5. Botão de Download
              if (isDownloadReady) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _downloadFile,
                  icon: const Icon(Icons.download),
                  label: const Text('BAIXAR RESULTADO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
