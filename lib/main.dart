import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:rotas/util/load_assets.dart'; // Mantido

// Função main (Ponto de entrada do aplicativo) - MANTIDO SIMPLES
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Processador Excel',
      home: ProcessamentoPage(),
    );
  }
}

// ----------------------------------------------------
// ProcessamentoPage
// ----------------------------------------------------

class ProcessamentoPage extends StatefulWidget {
  const ProcessamentoPage({super.key});

  @override
  State<ProcessamentoPage> createState() => _ProcessamentoPageState();
}

class _ProcessamentoPageState extends State<ProcessamentoPage> {
  final TextEditingController _numberController = TextEditingController();
  final Dio _dio = Dio();
  String? _selectedFilePath;
  String? _selectedFileName;
  double _progress = 0.0;
  Timer? _progressTimer;
  bool _isProcessing = false;
  // Instância do LoadAssets - OBRIGATÓRIA
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
    // Note: getJsonIps deve retornar Future<Map<String, dynamic>>. 
    // Foi corrigido para aceitar dynamic se a função for genérica.
    final Map<String, dynamic> data = await this.loadFileAsset.getJsonIps();
    return data[key] as String? ?? '';
  }

  // ----------------------------------------------------
  // Lógica de Polling de Progresso (VOID, recebe URL)
  // ----------------------------------------------------

  /// Controla o início e o fim da atualização da barra de progresso via polling.
  // Recebe a URL para não precisar carregá-la dentro do Timer.
  void controlProgressPolling(bool startPolling, String urlServer) {
    if (startPolling) {
      setState(() {
        _progress = 0.0;
        _isProcessing = true;
      });

      _progressTimer?.cancel();

      // O CALLBACK DO TIMER É ASYNC
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        try {
          final response = await _dio.get(
            // USA A URL JÁ CARREGADA
            '$urlServer/api/progresso', 
          );

          if (mounted) {
            final newProgress =
                (response.data['percentage'] as num).toDouble() / 100.0;
            setState(() {
              _progress = newProgress;
            });

            if (newProgress == 1.0) {
              _stopProgressPolling();
            }
          }
        } catch (e) {
          print('Erro ao buscar progresso: $e');
          // Para o polling em caso de erro de conexão persistente
          _stopProgressPolling(); 
          setState(() {
            _isProcessing = false;
          });
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
  // Lógica de Seleção de Arquivo (Inalterada)
  // ----------------------------------------------------
  Future<void> _selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    } else if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedFilePath = 'WEB_FILE_READY';
        _selectedFileName = result.files.single.name;
      });
    }
  }

  // ----------------------------------------------------
  // Lógica de Processamento e Download (ASYNC)
  // ----------------------------------------------------

  // 💡 MANTIDO ASYNC
  Future<void> processSheet() async {
    if (_selectedFileName == null ||
        _numberController.text.isEmpty ||
        _isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um arquivo e digite um número.'),
        ),
      );
      return;
    }

    // 1. OBTÉM O IP DO SERVIDOR ANTES DE QUALQUER COISA
    final String serverUrl = await this.getUrlServer();
    if (serverUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: IP do servidor não configurado.')),
        );
        return;
    }

    // 2. INICIA O POLLING com a URL JÁ CARREGADA
    this.controlProgressPolling(true, serverUrl);

    try {
      final MultipartFile fileData = await this._getFileData();
      final FormData formData = FormData.fromMap({
        'numero': _numberController.text,
        'file': fileData,
      });

      // 3. Requisição de Processamento
      final response = await _dio.post(
        '$serverUrl/api/processar',
        data: formData,
      );

      // 4. Download
      if (response.statusCode == 200 &&
          response.data['download_path'] != null) {
        final downloadPath = response.data['download_path'];
        await _downloadFile(downloadPath, serverUrl); // Passa a URL para o download
      } else {
        // ... (Tratamento de erro)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro no processamento: ${response.data['error'] ?? 'Desconhecido'}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Erro no processamento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha na comunicação com o servidor: $e')),
      );
      setState(() {
        _progress = 0.0; // Zera em caso de erro de conexão
      });
    } finally {
      // 5. PARA O POLLING
      controlProgressPolling(false, serverUrl);
    }
  }

  // Auxiliar para obter o MultipartFile (Inalterado)
  Future<MultipartFile> _getFileData() async {
    // ... (lógica inalterada) ...
    if (_selectedFilePath == 'WEB_FILE_READY') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        return MultipartFile.fromBytes(
          result.files.single.bytes!,
          filename: result.files.single.name,
        );
      }
      throw Exception("Falha ao obter dados do arquivo para upload.");
    } else {
      return await MultipartFile.fromFile(
        _selectedFilePath!,
        filename: _selectedFileName,
      );
    }
  }

  // 💡 RECEBE A URL COMO ARGUMENTO
  Future<void> _downloadFile(String filename, String serverUrl) async {
    try {
      // Rota de Download
      final downloadUrl = '$serverUrl/api/download/$filename';

      // Criar um link e disparar o download no navegador
      final anchor = html.AnchorElement(href: downloadUrl)
        ..setAttribute("download", filename)
        ..click();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download de "$filename" iniciado!')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Processador Excel - Flutter/FastAPI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Barra de Progresso (Sempre visível)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey[300],
                color: _isProcessing
                    ? Colors.blue
                    : (_progress == 1.0 ? Colors.green : Colors.grey),
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

              // 3. Caixa de Texto (Apenas Números)
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
                onPressed: _isProcessing ? null : processSheet,
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
            ],
          ),
        ),
      ),
    );
  }
}
