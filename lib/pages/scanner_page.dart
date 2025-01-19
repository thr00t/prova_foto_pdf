
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;

class ScannerPage extends StatefulWidget {
  final CameraDescription camera;

  const ScannerPage({super.key, required this.camera});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  static const String appFolderName = "PhotoToPDF";

  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await _controller.initialize();
      await _richiediPermessi();
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _richiediPermessi() async {
    await Permission.camera.request();
    await Permission.storage.request();
  }

  Future<String> _getDirectoryPubblica() async {
    if (Platform.isAndroid) {
      final documentsPath = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOCUMENTS,
      );
      final directory = Directory('$documentsPath/$appFolderName');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory.path;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final publicDir = Directory('${directory.path}/$appFolderName');
      if (!await publicDir.exists()) {
        await publicDir.create(recursive: true);
      }
      return publicDir.path;
    }
    throw UnsupportedError('Piattaforma non supportata.');
  }

  Future<File> _comprimiFoto(String fotoPath) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(dir.path, 'compressed_${path.basename(fotoPath)}');

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        fotoPath,
        targetPath,
        quality: 85,  // Comprensione al 85%
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw Exception('Compressione immagine fallita');
      }

      return File(result.path);
    } catch (e) {
      print('Errore con la compressione dell\'immagine: $e');
      // Se la compressione fallisce, ritorna l'immagine originale
      return File(fotoPath);
    }
  }


  Future<void> _scattaFotoECreaPDF(BuildContext context) async {
    try {
      await _initializeControllerFuture;
      final foto = await _controller.takePicture();

      // Comprimi l'immagine
      final fotoCompressa = await _comprimiFoto(foto.path);

      // Create PDF
      final pdf = pw.Document();
      final fotoBytes = await fotoCompressa.readAsBytes();
      final pdfFoto = pw.MemoryImage(fotoBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfFoto),
            );
          },
        ),
      );

      // Salvataggio nella cartella Documenti pubblica.
      final publicDir = await _getDirectoryPubblica();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfPath = '$publicDir/scan_$timestamp.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      // Pulizia dei file temporanei delle foto.
      await File(foto.path).delete();
      if (foto.path != fotoCompressa.path) {
        await fotoCompressa.delete();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF salvato con successo!'),
            action: SnackBarAction(
              label: 'Apri PDF',
              onPressed: () async {
                try {
                  final result = await OpenFile.open(pdfPath);
                  if (result.type != ResultType.done) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Impossibile aprire il file'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Errore durante l\'apertura del file'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Errore durante la scansione della foto: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante la scansione')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Foto su PDF Test'),
    ),
    body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 1.1,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        }
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _scattaFotoECreaPDF(context),
      child: const Icon(Icons.camera),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}