// lib/pages/home_page.dart (ou o nome do seu arquivo)

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // NOVO: Usa http com alias
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert'; // Para JSON
import 'package:rotas/util/load_assets.dart'; // Certifique-se de que o caminho está correto

// ----------------------------------------------------
// ProcessamentoPage (Usando HTTP)
// ----------------------------------------------------

class ProcessamentoPage extends StatefulWidget {
  const ProcessamentoPage({super.key});

  @override
  State<ProcessamentoPage> createState() => _ProcessamentoPageState();
}

class _ProcessamentoPageState extends State<ProcessamentoPage> {
  final TextEditingController _numberController = TextEditingController();

  PlatformFile? _xlsxFile;
  String? _selectedFileName;

  double _progress = 0.0;
  Timer? _progressTimer;
  bool _isProcessing = false;
  String? _idProcess;

  // A classe LoadAssets deve ser acessível e implementada corretamente.
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
    final Map<String, String> data = await this.loadFileAsset.getJsonIps();
    return data[key] ?? '';
  }

  // ----------------------------------------------------
  // Lógica de Seleção de Arquivo 📁
  // ----------------------------------------------------
  Future<void> _selectFile() async {
    // Carrega os bytes se for Web
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: kIsWeb,
    );

    if (result != null) {
      final file = result.files.single;

      if (kIsWeb && file.bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Erro: Arquivo Web não contém dados.')),
          );
          return;
      }

      setState(() {
          _xlsxFile = file;
          _selectedFileName = file.name;
      });
    }
  }

  // ----------------------------------------------------
  // Lógica de Polling de Progresso (AGORA USA HTTP)
  // ----------------------------------------------------

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

          final url = Uri.parse('$urlServer/$rtProg?id_process=$taskId');
          final response = await http.get(url);

          if (response.statusCode == 200 && mounted) {
            final Map<String, dynamic> data = jsonDecode(response.body);
            final newProgress = double.parse(data['progress']);
            final bool isDone = data['done'] as bool;

            setState(() {
              _progress = newProgress;
            });
            if (isDone) { // 🟢 Verificar o novo status de conclusão
              _stopProgressPolling();
              setState(() {
                _isProcessing = false;
              });
            }

            if (newProgress >= 1.0) {
              _stopProgressPolling();
              setState(() {
                _isProcessing = false;
              });
            }
          } else if (response.statusCode != 200) {
            throw Exception("Status ${response.statusCode}");
          }
        } catch (e) {
          print('Erro ao buscar progresso (HTTP): $e');
          _stopProgressPolling();
          setState(() {
            _isProcessing = false;
            _progress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Falha ao monitorar progresso (HTTP): $e')),
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
  // Lógica de Processamento e Download (AGORA USA HTTP)
  // ----------------------------------------------------

  Future<void> processSheet() async {
    if (_xlsxFile == null || _numberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_xlsxFile == null ?
            'Selecione um arquivo Excel para prosseguir.' :
            'Digite um número para prosseguir.'),
        ),
      );
      return;
    }

    if (_isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operação em andamento, aguarde.')),
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
      final PlatformFile file = _xlsxFile!;
      final url = Uri.parse('$serverUrl/$rtProcess');

      // 1. Criar a requisição Multipart
      final request = http.MultipartRequest('POST', url);

      // 2. Adicionar o campo 'numero'
      request.fields['numero'] = _numberController.text;

      // 3. Adicionar o arquivo 'file'
      if (kIsWeb) {
          // Web: Usa bytes
          request.files.add(http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name
          ));
      } else {
          // Mobile/Desktop: Usa path
          request.files.add(await http.MultipartFile.fromPath(
              'file',
              file.path!,
              filename: file.name
          ));
      }

      // 4. Enviar e aguardar a resposta
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['id_process'] != null) {
          final String taskId = data['id_process'].toString();
          this.controlProgressPolling(true, serverUrl, taskId);

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Processamento iniciado. ID: $taskId')),
          );
        } else {
          throw Exception(data['error'] ?? 'ID de processo ausente.');
        }
      } else {
        // Trata erros de status HTTP (4xx, 5xx)
        this.controlProgressPolling(false, serverUrl, '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro HTTP ${response.statusCode}: ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Erro no processamento/conexão (HTTP): $e');
      this.controlProgressPolling(false, serverUrl, '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha na comunicação com o servidor (HTTP): $e')),
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

      final downloadUrl = '$serverUrl/$rtDownload?id_process=$_idProcess';

      // Lógica de download específica para Web (usando universal_html)
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
    final bool isFileSelected = _xlsxFile != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Processador Excel - Flutter/FastAPI (HTTP)')),
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
                  backgroundColor: isFileSelected ? Colors.indigo[100] : Colors.grey[300],
                  foregroundColor: isFileSelected ? Colors.indigo : Colors.black87,
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
                onPressed: _isProcessing || isDownloadReady || !isFileSelected
                    ? null
                    : processSheet,
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
