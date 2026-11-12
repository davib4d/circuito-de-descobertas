import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/checkin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/resultado_sheet.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _registrando = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _aoDetectar(BarcodeCapture captura) async {
    if (_registrando || captura.barcodes.isEmpty) return;
    final conteudo = captura.barcodes.first.rawValue;
    if (conteudo == null) return;

    setState(() => _registrando = true);
    await _camera.stop();
    final resultado = await CheckinService.instance.registrar(conteudo);
    if (!mounted) return;

    if (resultado.status == CheckinStatus.sucesso) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    final escolha = await mostrarResultado(context, resultado);
    if (!mounted) return;

    // Folha fechada por gesto: depois de um sucesso volta, senão tenta de novo.
    final lerOutro = escolha ?? resultado.status != CheckinStatus.sucesso;
    if (lerOutro) {
      setState(() => _registrando = false);
      await _camera.start();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.uva,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camera,
              onDetect: _aoDetectar,
              errorBuilder: (context, erro) => _SemCamera(erro: erro),
            ),
            const IgnorePointer(child: CustomPaint(painter: _MolduraPainter())),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _BotaoRedondo(
                          icone: Icons.arrow_back_rounded,
                          rotulo: 'Voltar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        _BotaoRedondo(
                          icone: Icons.flashlight_on_rounded,
                          rotulo: 'Lanterna',
                          onPressed: _camera.toggleTorch,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_registrando) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Text(
                              _registrando
                                  ? 'Registrando sua visita…'
                                  : 'Aponte para o QR code do estande',
                              style: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  const _BotaoRedondo({required this.icone, required this.rotulo, required this.onPressed});

  final IconData icone;
  final String rotulo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: rotulo,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.uva,
        minimumSize: const Size(48, 48),
      ),
      onPressed: onPressed,
      icon: Icon(icone),
    );
  }
}

class _SemCamera extends StatelessWidget {
  const _SemCamera({required this.erro});

  final MobileScannerException erro;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final semPermissao = erro.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: AppColors.uva,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, color: Colors.white, size: 52),
              const SizedBox(height: 16),
              Text(
                semPermissao ? 'Câmera sem permissão' : 'Câmera indisponível',
                textAlign: TextAlign.center,
                style: texto.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                semPermissao
                    ? 'Libere o acesso à câmera nas configurações do Android para ler o QR code do estande.'
                    : 'Feche outros apps que estejam usando a câmera e abra o leitor de novo.',
                textAlign: TextAlign.center,
                style: texto.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Escurece a imagem e abre uma janela arredondada para enquadrar o QR.
class _MolduraPainter extends CustomPainter {
  const _MolduraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.width * 0.7;
    final janela = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.45),
        width: lado,
        height: lado,
      ),
      const Radius.circular(36),
    );
    final veu = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(janela),
    );
    canvas.drawPath(veu, Paint()..color = AppColors.uva.withValues(alpha: 0.62));
    canvas.drawRRect(
      janela,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = AppColors.menta,
    );
  }

  @override
  bool shouldRepaint(_MolduraPainter antigo) => false;
}
