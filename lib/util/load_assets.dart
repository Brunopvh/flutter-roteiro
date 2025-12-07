import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

class LoadAssets {
  late File fileAssetIps; // = File('assets/data/ips.json');
  late Directory dirAssets;

  LoadAssets(Directory dirAssets) {
    this.dirAssets = dirAssets;
    this.fileAssetIps = File(
      path.join(this.dirAssets.path, 'data', 'ips.json'),
    );
  }

  File getFileAssetIps() {
    return this.fileAssetIps;
  }

  Directory getDirAssets() {
    return this.dirAssets;
  }

  Future<Map<String, String>> getJsonIps() async {
    String jsonData = await rootBundle.loadString(this.fileAssetIps.path);
    return json.decode(jsonData) as Map<String, String>;
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
