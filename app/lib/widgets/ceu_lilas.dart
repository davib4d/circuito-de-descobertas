import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fundo da referência: degradê lilás com bolhas e nuvens soltas.
class CeuLilas extends StatelessWidget {
  const CeuLilas({super.key, required this.child, this.borderRadius = BorderRadius.zero});

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.lilas, AppColors.lilasForte],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -40,
              child: _Bolha(diametro: 190, cor: Colors.white.withValues(alpha: 0.14)),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: _Bolha(diametro: 230, cor: const Color(0xFF7E50D6).withValues(alpha: 0.32)),
            ),
            Positioned(
              top: 64,
              right: 26,
              child: Nuvem(largura: 62, cor: Colors.white.withValues(alpha: 0.38)),
            ),
            const Positioned(
              bottom: 22,
              right: 34,
              child: Nuvem(largura: 78, cor: AppColors.menta),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _Bolha extends StatelessWidget {
  const _Bolha({required this.diametro, required this.cor});

  final double diametro;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
    );
  }
}

class Nuvem extends StatelessWidget {
  const Nuvem({super.key, required this.largura, required this.cor});

  final double largura;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(largura, largura * 0.46), painter: _NuvemPainter(cor));
  }
}

class _NuvemPainter extends CustomPainter {
  const _NuvemPainter(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()..color = cor;
    final w = size.width;
    final h = size.height;
    // saveLayer evita que as formas sobrepostas escureçam cores translúcidas.
    canvas.saveLayer(Offset.zero & size, Paint());
    final solido = Paint()..color = cor.withValues(alpha: 1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.5, w, h * 0.5), Radius.circular(h * 0.25)),
      solido,
    );
    canvas.drawCircle(Offset(w * 0.32, h * 0.52), h * 0.32, solido);
    canvas.drawCircle(Offset(w * 0.6, h * 0.42), h * 0.42, solido);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = tinta.color
        ..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NuvemPainter antigo) => antigo.cor != cor;
}

/// Selo redondo branco usado como marca do app.
class Selo extends StatelessWidget {
  const Selo({super.key, this.diametro = 44});

  final double diametro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.22), spreadRadius: diametro * 0.14),
        ],
      ),
      child: Icon(Icons.star_rounded, color: AppColors.lilasForte, size: diametro * 0.58),
    );
  }
}
