import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';
import '../services/circuito_store.dart';
import '../theme/app_theme.dart';
import '../widgets/estande_card.dart';
import 'scanner_screen.dart';

class MissaoScreen extends StatefulWidget {
  const MissaoScreen({super.key});

  @override
  State<MissaoScreen> createState() => _MissaoScreenState();
}

class _MissaoScreenState extends State<MissaoScreen> {
  final _store = CircuitoStore.instance;

  @override
  void initState() {
    super.initState();
    // Registra a abertura da missão no Analytics.
    AnalyticsService.instance
        .missaoAberta(quantidadeDeEstandes: _store.estandesDaMissao.length)
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) =>
                _store.missaoAtiva ? _Conteudo(store: _store) : const _Encerrada(),
          ),
        ),
      ),
    );
  }
}

class _Voltar extends StatelessWidget {
  const _Voltar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Voltar',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.uvaSuave),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.store});

  final CircuitoStore store;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final participantes = store.estandesDaMissao;
    final total = participantes.length;
    final feitos = store.visitadosNaMissao;
    final progresso = total == 0 ? 0.0 : feitos / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const _Voltar(),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _Anel(progresso: progresso),
              const SizedBox(width: 12),
              Text(
                '${(progresso * 100).round()}%',
                style: texto.titleSmall?.copyWith(
                  color: AppColors.uvaSuave,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ScannerScreen()),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text('Ler QR code'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            store.missao.titulo,
            style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _Indicador(icone: Icons.star_rounded, rotulo: 'Em destaque', valor: total),
            ),
            Expanded(
              child: _Indicador(icone: Icons.check_rounded, rotulo: 'Visitados', valor: feitos),
            ),
            Expanded(
              child: _Indicador(
                icone: Icons.directions_walk_rounded,
                rotulo: 'Faltam',
                valor: total - feitos,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            total > 0 && feitos == total
                ? 'Missão concluída. Você passou por todos os estandes em destaque.'
                : store.missao.descricao,
            style: texto.bodyMedium?.copyWith(color: AppColors.uvaSuave, height: 1.5),
          ),
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Estandes participantes',
            style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (participantes.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.lilasFundo,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Nenhum estande ativo foi selecionado para esta missão ainda.',
              style: texto.bodyMedium?.copyWith(color: AppColors.uvaSuave),
            ),
          )
        else
          GramadoDeEstandes(
            children: [
              for (final estande in participantes)
                EstandeCard(
                  key: ValueKey(estande.id),
                  estande: estande,
                  visitado: store.visitado(estande),
                ),
            ],
          ),
      ],
    );
  }
}

class _Anel extends StatelessWidget {
  const _Anel({required this.progresso});

  final double progresso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progresso),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, valor, _) => SizedBox.expand(
              child: CircularProgressIndicator(
                value: valor,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: AppColors.menta,
                backgroundColor: AppColors.lilasFundo,
              ),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(color: AppColors.lilasNevoa, shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded, color: AppColors.lilasForte, size: 36),
          ),
        ],
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.icone, required this.rotulo, required this.valor});

  final IconData icone;
  final String rotulo;
  final int valor;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: AppColors.lilas, shape: BoxShape.circle),
          child: Icon(icone, color: Colors.white, size: 19),
        ),
        const SizedBox(height: 8),
        Text(rotulo, style: texto.labelSmall?.copyWith(color: AppColors.uvaSuave)),
        const SizedBox(height: 2),
        Text(
          '$valor',
          style: texto.headlineSmall?.copyWith(
            color: AppColors.mentaTexto,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// A organização desligou a missão com esta tela aberta.
class _Encerrada extends StatelessWidget {
  const _Encerrada();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          const _Voltar(),
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: AppColors.lilasNevoa, shape: BoxShape.circle),
            child: const Icon(Icons.nightlight_round, color: AppColors.lilasForte, size: 42),
          ),
          const SizedBox(height: 18),
          Text(
            'A missão foi encerrada',
            textAlign: TextAlign.center,
            style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Os estandes continuam abertos e o check-in segue valendo.',
            textAlign: TextAlign.center,
            style: texto.bodyMedium?.copyWith(color: AppColors.uvaSuave, height: 1.45),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Voltar aos estandes'),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
