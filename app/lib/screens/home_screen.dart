import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/circuito_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ceu_lilas.dart';
import '../widgets/estande_card.dart';
import '../widgets/missao_banner.dart';
import 'missao_screen.dart';
import 'scanner_screen.dart';

String _plural(int n, String singular, String plural) => '$n ${n == 1 ? singular : plural}';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CircuitoStore.instance;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: const BotaoLerQr(),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _Cabecalho(store: store),
                // Aparece e some conforme o Remote Config, sem reabrir o app.
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: store.missaoAtiva
                        ? Padding(
                            key: const ValueKey('missao-ligada'),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                            child: MissaoBanner(
                              titulo: store.missao.titulo,
                              resumo: _resumoDaMissao(store),
                              onAbrir: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => const MissaoScreen()),
                              ),
                            ),
                          )
                        : const SizedBox(key: ValueKey('missao-desligada'), width: double.infinity),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
                  child: Text(
                    'Estandes do circuito',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Lista(store: store),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _resumoDaMissao(CircuitoStore store) {
    final total = store.estandesDaMissao.length;
    if (total == 0) return 'Toque para ver os detalhes.';
    final feitos = store.visitadosNaMissao;
    if (feitos == total) return 'Você visitou todos os estandes em destaque.';
    return '${_plural(total, 'estande em destaque', 'estandes em destaque')}, '
        '${_plural(feitos, 'visitado', 'visitados')}.';
  }
}

class BotaoLerQr extends StatelessWidget {
  const BotaoLerQr({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: null,
      backgroundColor: AppColors.coral,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: const StadiumBorder(),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 30),
      icon: const Icon(Icons.qr_code_scanner_rounded),
      label: Text(
        'Ler QR code',
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.store});

  final CircuitoStore store;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final topo = MediaQuery.paddingOf(context).top;
    final total = store.estandes.length;

    return CeuLilas(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(44)),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, topo + 22, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Selo(diametro: 40),
                  const SizedBox(width: 16),
                  Text(
                    'Amazon Hacking',
                    style: texto.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Circuito de\nDescobertas',
                style: texto.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Text(
                  'Passe pelos estandes e registre cada visita lendo o QR code.',
                  style: texto.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Contorno branco em pílula, como os campos da referência.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      total == 0
                          ? 'Nenhuma visita registrada'
                          : '${store.visitadosAtivos} de $total estandes visitados',
                      style: texto.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.store});

  final CircuitoStore store;

  @override
  Widget build(BuildContext context) {
    if (store.carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (store.falhou) {
      return const _Aviso(
        icone: Icons.cloud_off_rounded,
        titulo: 'Não foi possível carregar os estandes',
        mensagem: 'Verifique sua conexão. A lista volta sozinha quando a internet retornar.',
      );
    }
    if (store.estandes.isEmpty) {
      return const _Aviso(
        icone: Icons.storefront_rounded,
        titulo: 'Nenhum estande ativo agora',
        mensagem: 'Assim que a organização ativar um estande, ele aparece aqui.',
      );
    }
    return GramadoDeEstandes(
      children: [
        for (final estande in store.estandesOrdenados)
          EstandeCard(
            key: ValueKey(estande.id),
            estande: estande,
            visitado: store.visitado(estande),
            emDestaque: store.emDestaque(estande),
          ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.titulo, required this.mensagem});

  final IconData icone;
  final String titulo;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        children: [
          Icon(icone, size: 44, color: AppColors.lilas),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: texto.bodySmall?.copyWith(color: AppColors.uvaSuave, height: 1.4),
          ),
        ],
      ),
    );
  }
}
