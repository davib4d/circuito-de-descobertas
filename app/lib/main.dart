import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/boot_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CircuitoApp());
}

class CircuitoApp extends StatelessWidget {
  const CircuitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Circuito de Descobertas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro(),
      home: const BootScreen(),
    );
  }
}
