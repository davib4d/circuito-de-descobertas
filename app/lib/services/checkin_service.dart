import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/estande.dart';
import 'analytics_service.dart';
import 'missao_service.dart';

enum CheckinStatus { sucesso, qrInvalido, estandeInativo, jaRegistrado, erro }

class CheckinResultado {
  const CheckinResultado(this.status, {this.estande});
  final CheckinStatus status;
  final Estande? estande;
}

class CheckinService {
  CheckinService._();
  static final CheckinService instance = CheckinService._();

  /// Mesmo formato gerado pelo painel web (web-admin/app.js).
  static const prefixoQr = 'circuito://estande/';
  static final _idValido = RegExp(r'^[A-Za-z0-9_-]{1,40}$');

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Devolve o ID do estande ou `null` se o QR não for do Circuito.
  static String? extrairEstandeId(String conteudo) {
    final texto = conteudo.trim();
    if (!texto.startsWith(prefixoQr)) return null;
    final id = texto.substring(prefixoQr.length);
    return _idValido.hasMatch(id) ? id : null;
  }

  Future<CheckinResultado> registrar(String conteudoDoQr) async {
    final estandeId = extrairEstandeId(conteudoDoQr);
    if (estandeId == null) return const CheckinResultado(CheckinStatus.qrInvalido);

    final visitanteId = FirebaseAuth.instance.currentUser?.uid;
    if (visitanteId == null) return const CheckinResultado(CheckinStatus.erro);

    // 1. O estande existe e está ativo? Consulta direto no servidor.
    final Estande estande;
    try {
      final doc = await _db
          .collection('estandes')
          .doc(estandeId)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) return const CheckinResultado(CheckinStatus.qrInvalido);
      estande = Estande.fromDoc(doc);
      if (!estande.ativo) return CheckinResultado(CheckinStatus.estandeInativo, estande: estande);
    } on FirebaseException catch (e) {
      // As regras só deixam o visitante ler estandes ativos:
      // permission-denied aqui significa "existe, mas está inativo".
      if (e.code == 'permission-denied') {
        return const CheckinResultado(CheckinStatus.estandeInativo);
      }
      return const CheckinResultado(CheckinStatus.erro);
    }

    // 2. Chave composta visitante_estande: no máximo um check-in por par.
    final checkinRef = _db.collection('checkins').doc('${visitanteId}_$estandeId');
    try {
      final gravou = await _db.runTransaction<bool>((transacao) async {
        final atual = await transacao.get(checkinRef);
        if (atual.exists) return false;
        transacao.set(checkinRef, {
          'visitanteId': visitanteId,
          'estandeId': estandeId,
          'criadoEm': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!gravou) return CheckinResultado(CheckinStatus.jaRegistrado, estande: estande);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // O estande foi desativado entre a leitura e a gravação.
        return CheckinResultado(CheckinStatus.estandeInativo, estande: estande);
      }
      return CheckinResultado(CheckinStatus.erro, estande: estande);
    }

    // 3. Só depois da gravação confirmada o evento vai para o Analytics.
    final missao = MissaoService.instance;
    try {
      await AnalyticsService.instance.checkinConcluido(
        estandeId: estandeId,
        emMissao: missao.ativa && missao.estandes.contains(estandeId),
      );
    } catch (_) {
      // Falha de medição não desfaz um check-in já gravado.
    }
    return CheckinResultado(CheckinStatus.sucesso, estande: estande);
  }
}
