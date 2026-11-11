import 'package:circuito_descobertas/services/checkin_service.dart';
import 'package:circuito_descobertas/services/missao_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR code do estande', () {
    test('extrai o identificador do formato gerado pelo painel', () {
      expect(CheckinService.extrairEstandeId('circuito://estande/E03'), 'E03');
    });

    test('recusa QR codes de fora do circuito', () {
      expect(CheckinService.extrairEstandeId('https://exemplo.com'), isNull);
      expect(CheckinService.extrairEstandeId('E03'), isNull);
      expect(CheckinService.extrairEstandeId('circuito://estande/a/b'), isNull);
      expect(CheckinService.extrairEstandeId('circuito://estande/'), isNull);
    });
  });

  group('missao_estandes', () {
    test('aceita lista separada por vírgula', () {
      expect(MissaoService.interpretarEstandes('E01, E03'), {'E01', 'E03'});
    });

    test('aceita lista JSON', () {
      expect(MissaoService.interpretarEstandes('["E01","E02"]'), {'E01', 'E02'});
    });

    test('valor vazio não destaca nenhum estande', () {
      expect(MissaoService.interpretarEstandes('  '), isEmpty);
    });
  });
}
