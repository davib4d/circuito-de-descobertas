import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Chamada da missão surpresa na tela inicial. Só existe com `missao_ativa`.
class MissaoBanner extends StatelessWidget {
  const MissaoBanner({
    super.key,
    required this.titulo,
    required this.resumo,
    required this.onAbrir,
  });

  final String titulo;
  final String resumo;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: AppColors.lilasForte.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      resumo,
                      style: texto.bodySmall?.copyWith(color: AppColors.uvaSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.lilasFundo,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Abrir',
                  style: texto.labelLarge?.copyWith(
                    color: AppColors.lilasForte,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
