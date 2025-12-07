import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import 'package:flutter/services.dart';

// Substitua pelo IP/Porta do seu backend
const String _baseUrl = 'http://127.0.0.1:8000';

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

  @override
  void initState() {
    super.initState();
    // O polling não começa mais no initState.
  }

  @override
  void dispose() {
    // Garante que o timer seja cancelado ao sair da tela
    _progressTimer?.cancel();
    _numberController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------
  // Lógica de Polling de Progresso
  // ----------------------------------------------------

  /// Controla o início e o fim da atualização da barra de progresso via polling.
  void controlProgressPolling(bool startPolling) {
    if (startPolling) {
      // 1. Inicia/Reseta o progresso e o estado
      setState(() {
        _progress = 0.0;
        _isProcessing = true;
      });
      
      // 2. Cancela qualquer timer existente
      _progressTimer?.cancel();

      // 3. Inicia o novo polling a cada 1 segundo
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          final response = await _dio.get('$_baseUrl/api/progresso');
          
          if (mounted) {
            final newProgress = (response.data['percentage'] as num).toDouble() / 100.0;
            setState(() {
              _progress = newProgress;
            });

            // Se o progresso atingir 100%, paramos o polling.
            if (newProgress == 1.0) {
              _stopProgressPolling();
            }
          }
        } catch (e) {
          // Loga erro, mas não interrompe a UI
          print('Erro ao buscar progresso: $e');
        }
      });
    } else {
      // Para o polling e finaliza o estado de processamento
      _stopProgressPolling();
      setState(() {
        _isProcessing = false;
        // Se a operação foi bem-sucedida, o progresso deve estar em 1.0 (100%)
        // Se houve erro de rede/servidor, o progresso será mantido onde parou
        // ou você pode zerar aqui: _progress = 0.0;
      });
    }
  }

  void _stopProgressPolling() {
     _progressTimer?.cancel();
     _progressTimer = null;
  }

  // ----------------------------------------------------
  // Lógica de Seleção de Arquivo
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
      // Caso Web: o path é nulo, usamos o nome e bytes
       setState(() {
        _selectedFilePath = 'WEB_FILE_READY'; 
        _selectedFileName = result.files.single.name;
      });
    }
  }

  // ----------------------------------------------------
  // Lógica de Processamento e Download
  // ----------------------------------------------------

  Future<void> _processFile() async {
    if (_selectedFileName == null || _numberController.text.isEmpty || _isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um arquivo e digite um número.')),
      );
      return;
    }

    // 1. INICIA O POLLING e define _isProcessing = true
    controlProgressPolling(true); 

    try {
      // Prepara os dados
      final fileData = await _getFileData();
      final formData = FormData.fromMap({
        'numero': _numberController.text,
        'file': fileData,
      });

      // 2. Requisição de Processamento
      final response = await _dio.post('$_baseUrl/api/processar', data: formData);

      // 3. Download (A requisição só retorna 200 no backend SÍNCRONO após 100% de progresso)
      if (response.statusCode == 200 && response.data['download_path'] != null) {
        final downloadPath = response.data['download_path'];
        await _downloadFile(downloadPath);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro no processamento: ${response.data['error'] ?? 'Desconhecido'}')),
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
      // 4. PARA O POLLING e reseta o estado de processamento
      controlProgressPolling(false); 
    }
  }

  // Auxiliar para obter o MultipartFile, suportando Web
  Future<MultipartFile> _getFileData() async {
    if (_selectedFilePath == 'WEB_FILE_READY') {
      // Lógica para Flutter Web: precisa re-selecionar o arquivo para obter os bytes,
      // pois o FilePicker não mantém os bytes na memória após a primeira seleção
      // sem o WithData=true, e a chamada precisa ser separada para o Dio.
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
      // Lógica para outras plataformas (FilePicker armazena em path)
      return await MultipartFile.fromFile(
        _selectedFilePath!,
        filename: _selectedFileName,
      );
    }
  }

  Future<void> _downloadFile(String filename) async {
    try {
      // Rota de Download
      final downloadUrl = '$_baseUrl/api/download/$filename';

      // Criar um link e disparar o download no navegador (Necessário para Flutter Web)
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
      appBar: AppBar(
        title: const Text('Processador Excel - Flutter/FastAPI'),
      ),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // 2. Botão para Selecionar Excel
              ElevatedButton.icon(
                onPressed: _selectFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_selectedFileName ?? 'Selecionar Planilha Excel (.xlsx)'),
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
                onPressed: _isProcessing ? null : _processFile,
                icon: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
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

// ----------------------------------------------------
// Função main (Ponto de entrada do aplicativo)
// ----------------------------------------------------

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Processador Excel',
      home: const ProcessamentoPage(), 
    );
  }
}