import 'package:firebase_analytics/firebase_analytics.dart';

/// Eventos avaliados na atividade. Os nomes aparecem no relatório
/// Tempo real do GA4 exatamente como estão aqui.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _ga => FirebaseAnalytics.instance;

  Future<void> missaoAberta({required int quantidadeDeEstandes}) {
    return _ga.logEvent(
      name: 'missao_aberta',
      parameters: <String, Object>{'qtd_estandes': quantidadeDeEstandes},
    );
  }

  Future<void> checkinConcluido({required String estandeId, required bool emMissao}) {
    return _ga.logEvent(
      name: 'checkin_concluido',
      parameters: <String, Object>{
        'estande_id': estandeId,
        'em_missao': emMissao ? 'sim' : 'nao',
      },
    );
  }
}
