import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:muse_mate/config/firebase_options.dart';
import 'package:muse_mate/screen/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'lib/config/.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
