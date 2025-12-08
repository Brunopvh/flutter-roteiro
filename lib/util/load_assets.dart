import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

class LoadAssets {
  late String fileAssetIps; // = File('assets/data/ips.json');
  late Directory dirAssets;

  LoadAssets(Directory dirAssets) {
    this.dirAssets = dirAssets;
    this.fileAssetIps = path.join(this.dirAssets.path, 'data', 'ips.json');
  }

  String getFileAssetIps() {
    return this.fileAssetIps;
  }

  Directory getDirAssets() {
    return this.dirAssets;
  }

  Future<Map<String, String>> getJsonIps() async {
    String jsonData = await rootBundle.loadString(this.fileAssetIps);
    final data = json.decode(jsonData) as Map<String, dynamic>;
    // Mapeia os valores do Map<String, dynamic> para Map<String, String>.
    try {
      final Map<String, String> stringMap = data.map((key, value) {
        // Tenta converter o valor para String. Se for nulo ou outro tipo,
        // o 'toString()' é uma forma segura (mas bruta) de garantir uma String.
        // O cast 'as String' é mais seguro se você tiver certeza de que é uma String.
        return MapEntry(key, value.toString());
      });
      return stringMap;
    } catch (e) {
      // Adiciona um tratamento de erro caso a conversão falhe por algum motivo inesperado
      throw FormatException('Erro ao converter dados do JSON para Map<String, String>: $e');
    }
  }

  Future<String> getRouteProcessExcel() async {
    Map<String, String> data = await this.getJsonIps();
    return data["rt_process_excel"] ?? "";
  }

  Future<String> getRouteProgress() async {
    Map<String, String> data = await this.getJsonIps();
    return data["rt_progress"] ?? "";
  }

  Future<String> getRouteDownload() async {
    Map<String, String> data = await this.getJsonIps();
    return data["rt_download"] ?? "";
  }

  void saveJson(String fileName, Map<String, dynamic> data) {
    // Salvar arquivos json na pasta assets em assets/data/output
    Directory outputDir = Directory(
      path.join(this.getDirAssets().path, 'data', 'output'),
    );
    if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true); // Adicionado recursive: true por segurança
    }
    String actualFileName = fileName.endsWith('.json') ? fileName : '$fileName.json';
    File outputFile = File(path.join(outputDir.path, actualFileName));
    //Converte o Map em uma string JSON formatada
    String jsonString = json.encode(data);    
    outputFile.writeAsStringSync(jsonString);
    print('JSON salvo com sucesso em: ${outputFile.path}');
  }

  factory LoadAssets.create ({String dirAssets = 'assets'}){
    return LoadAssets(Directory(dirAssets));
  }
}
