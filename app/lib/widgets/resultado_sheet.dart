import 'package:flutter/material.dart';

import '../services/checkin_service.dart';
import '../theme/app_theme.dart';

/// Mostra o retorno do check-in. Devolve `true` se a pessoa quer ler outro QR.
Future<bool?> mostrarResultado(BuildContext context, CheckinResultado resultado) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ResultadoSheet(resultado),
  );
}

class _ResultadoSheet extends StatelessWidget {
  const _ResultadoSheet(this.resultado);

  final CheckinResultado resultado;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final nome = resultado.estande?.nome;

    final (IconData icone, Color fundo, Color cor, String titulo, String mensagem) =
        switch (resultado.status) {
      CheckinStatus.sucesso => (
          Icons.check_rounded,
          AppColors.menta,
          const Color(0xFF17502F),
          'Check-in concluído',
          'Sua visita ao estande $nome foi registrada.',
        ),
      CheckinStatus.jaRegistrado => (
          Icons.event_available_rounded,
          AppColors.lilasNevoa,
          AppColors.lilasForte,
          'Visita já registrada',
          'Você já fez check-in em $nome. Cada estande conta uma vez por visitante.',
        ),
      CheckinStatus.estandeInativo => (
          Icons.pause_rounded,
          AppColors.lilasNevoa,
          AppColors.uvaSuave,
          'Estande inativo',
          'Este estande não está recebendo visitas agora. Procure outro estande do circuito.',
        ),
      CheckinStatus.qrInvalido => (
          Icons.qr_code_2_rounded,
          const Color(0xFFFFE3E1),
          AppColors.coral,
          'QR code inválido',
          'Este código não pertence a um estande do Circuito de Descobertas.',
        ),
      CheckinStatus.erro => (
          Icons.wifi_off_rounded,
          const Color(0xFFFFE3E1),
          AppColors.coral,
          'Não foi possível registrar',
          'Verifique sua conexão com a internet e leia o QR code de novo.',
        ),
    };

    final sucesso = resultado.status == CheckinStatus.sucesso;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
              child: Icon(icone, color: cor, size: 46),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: texto.bodyMedium?.copyWith(color: AppColors.uvaSuave, height: 1.45),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(!sucesso),
                child: Text(sucesso ? 'Voltar aos estandes' : 'Ler outro QR code'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(sucesso),
                child: Text(sucesso ? 'Ler outro QR code' : 'Voltar aos estandes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
