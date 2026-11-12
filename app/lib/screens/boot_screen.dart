import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../firebase_options.dart';
import '../services/circuito_store.dart';
import '../services/missao_service.dart';
import '../widgets/ceu_lilas.dart';
import 'home_screen.dart';

/// Abre o Firebase, cria a sessão anônima do visitante e carrega a missão.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  String? _erro;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    if (_erro != null) setState(() => _erro = null);
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final auth = FirebaseAuth.instance;
      final visitante = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (visitante == null) throw StateError('Sessão anônima não criada.');

      await MissaoService.instance.iniciar();
      CircuitoStore.instance.iniciar(visitante.uid);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    } catch (erro) {
      debugPrint('Falha na abertura: $erro');
      if (!mounted) return;
      setState(() {
        _erro = erro is UnsupportedError
            ? (erro.message ?? 'Firebase não configurado.')
            : 'Não foi possível conectar. Verifique a internet e tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CeuLilas(
          child: SizedBox.expand(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Selo(diametro: 84),
                    const SizedBox(height: 34),
                    Text(
                      'Circuito de\nDescobertas',
                      textAlign: TextAlign.center,
                      style: texto.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Amazon Hacking',
                      style: texto.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 44),
                    if (_erro == null)
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.5),
                      )
                    else ...[
                      Text(
                        _erro!,
                        textAlign: TextAlign.center,
                        style: texto.bodyMedium?.copyWith(color: Colors.white, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF23824A),
                        ),
                        onPressed: _iniciar,
                        child: const Text('Tentar de novo'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
