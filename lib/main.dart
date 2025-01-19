import 'package:flutter/material.dart';
import 'package:flutter_photo_pdf/app.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(App(camera: cameras.first));
}
