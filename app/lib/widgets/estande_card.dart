import 'package:material_ui/material_ui.dart';

import '../models/estande.dart';
import '../theme/app_theme.dart';

class EstandeCard extends StatelessWidget {
  const EstandeCard({
    super.key,
    required this.estande,
    required this.visitado,
    this.emDestaque = false,
  });

  final Estande estande;
  final bool visitado;
  final bool emDestaque;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emDestaque ? AppColors.coral : Colors.white,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: visitado ? AppColors.menta : AppColors.mentaClara,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              visitado ? Icons.check_rounded : Icons.storefront_rounded,
              color: visitado ? const Color(0xFF17502F) : AppColors.mentaTexto,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (emDestaque) ...[
                  const _Etiqueta(
                    icone: Icons.star_rounded,
                    rotulo: 'Em missão',
                    fundo: AppColors.coral,
                    cor: Colors.white,
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  estande.nome,
                  style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 15, color: AppColors.lilasForte),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        estande.localizacao,
                        style: texto.bodySmall?.copyWith(
                          color: AppColors.lilasForte,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (estande.descricao.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    estande.descricao,
                    style: texto.bodySmall?.copyWith(color: AppColors.uvaSuave, height: 1.4),
                  ),
                ],
                if (visitado) ...[
                  const SizedBox(height: 8),
                  const _Etiqueta(
                    icone: Icons.check_circle_rounded,
                    rotulo: 'Visita registrada',
                    fundo: AppColors.mentaClara,
                    cor: AppColors.mentaTexto,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({
    required this.icone,
    required this.rotulo,
    required this.fundo,
    required this.cor,
  });

  final IconData icone;
  final String rotulo;
  final Color fundo;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 12, 3),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(
            rotulo,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: cor, fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Bloco menta que agrupa os cartões, como a área de destaques da referência.
class GramadoDeEstandes extends StatelessWidget {
  const GramadoDeEstandes({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mentaClara,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}
