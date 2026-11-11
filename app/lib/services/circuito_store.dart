import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/estande.dart';
import 'missao_service.dart';

/// Estado da tela: estandes ativos (Firestore), check-ins do próprio visitante
/// (Firestore) e missão (Remote Config), tudo em tempo real.
class CircuitoStore extends ChangeNotifier {
  CircuitoStore._();
  static final CircuitoStore instance = CircuitoStore._();

  final MissaoService missao = MissaoService.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subEstandes;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subCheckins;
  bool _ouvindoMissao = false;

  List<Estande> estandes = const [];
  Set<String> visitados = const {};
  bool carregando = true;
  bool falhou = false;

  void iniciar(String visitanteId) {
    if (!_ouvindoMissao) {
      missao.addListener(notifyListeners);
      _ouvindoMissao = true;
    }

    _subEstandes?.cancel();
    _subEstandes = _db
        .collection('estandes')
        .where('ativo', isEqualTo: true)
        .snapshots()
        .listen((foto) {
      estandes = foto.docs.map(Estande.fromDoc).toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      carregando = false;
      falhou = false;
      notifyListeners();
    }, onError: (Object erro) {
      debugPrint('Estandes: $erro');
      carregando = false;
      falhou = true;
      notifyListeners();
    });

    _subCheckins?.cancel();
    _subCheckins = _db
        .collection('checkins')
        .where('visitanteId', isEqualTo: visitanteId)
        .snapshots()
        .listen((foto) {
      visitados = foto.docs.map((d) => d.data()['estandeId'] as String).toSet();
      notifyListeners();
    }, onError: (Object erro) => debugPrint('Check-ins: $erro'));
  }

  bool get missaoAtiva => missao.ativa;

  bool emDestaque(Estande estande) => missaoAtiva && missao.estandes.contains(estande.id);

  bool visitado(Estande estande) => visitados.contains(estande.id);

  /// Estandes ativos selecionados para a missão. IDs inexistentes ou de
  /// estandes inativos no Remote Config são simplesmente ignorados.
  List<Estande> get estandesDaMissao =>
      missaoAtiva ? estandes.where(emDestaque).toList() : const [];

  /// Com a missão ligada, os destaques sobem para o topo da lista.
  List<Estande> get estandesOrdenados {
    if (!missaoAtiva) return estandes;
    return [...estandes.where(emDestaque), ...estandes.where((e) => !emDestaque(e))];
  }

  int get visitadosNaMissao => estandesDaMissao.where(visitado).length;

  int get visitadosAtivos => estandes.where(visitado).length;
}
