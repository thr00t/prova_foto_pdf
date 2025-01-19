import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_photo_pdf/pages/scanner_page.dart';

class App extends StatelessWidget {
  final CameraDescription camera;

  const App({super.key, required this.camera});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Prova Foto To PDF',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: false,
    ),
    home: ScannerPage(camera: camera),
    debugShowCheckedModeBanner: false,
  );
}