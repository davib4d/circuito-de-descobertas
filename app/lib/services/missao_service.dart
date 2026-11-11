import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Lê a missão surpresa do Remote Config e avisa a interface quando a
/// organização publica uma alteração, sem reinstalar nem reabrir o app.
class MissaoService extends ChangeNotifier {
  MissaoService._();
  static final MissaoService instance = MissaoService._();

  static const chaveAtiva = 'missao_ativa';
  static const chaveEstandes = 'missao_estandes';
  static const chaveTitulo = 'missao_titulo';
  static const chaveDescricao = 'missao_descricao';

  static const tituloPadrao = 'Missão surpresa';
  static const descricaoPadrao =
      'Visite os estandes em destaque e registre sua passagem pelo QR code.';

  /// Padrão local: a missão começa desligada.
  static const Map<String, dynamic> padroes = {
    chaveAtiva: false,
    chaveEstandes: '',
    chaveTitulo: tituloPadrao,
    chaveDescricao: descricaoPadrao,
  };

  FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;
  StreamSubscription<RemoteConfigUpdate>? _atualizacoes;

  bool ativa = false;
  Set<String> estandes = const {};
  String titulo = tituloPadrao;
  String descricao = descricaoPadrao;

  Future<void> iniciar() async {
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 15),
      minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(minutes: 1),
    ));
    await _rc.setDefaults(padroes);
    _ler();

    try {
      await _rc.fetchAndActivate();
      _ler();
    } catch (erro) {
      // Sem rede na abertura: segue com o padrão local (missão desligada).
      debugPrint('Remote Config: busca inicial falhou ($erro)');
    }

    // Atualização em tempo real: cada publicação no console chega aqui.
    _atualizacoes ??= _rc.onConfigUpdated.listen(
      (_) async {
        await _rc.activate();
        _ler();
      },
      onError: (Object erro) => debugPrint('Remote Config em tempo real: $erro'),
    );
  }

  void _ler() {
    ativa = _rc.getBool(chaveAtiva);
    estandes = interpretarEstandes(_rc.getString(chaveEstandes));
    final t = _rc.getString(chaveTitulo).trim();
    final d = _rc.getString(chaveDescricao).trim();
    titulo = t.isEmpty ? tituloPadrao : t;
    descricao = d.isEmpty ? descricaoPadrao : d;
    notifyListeners();
  }

  /// Aceita "E01,E03", "E01; E03", "E01 E03" ou uma lista JSON `["E01","E03"]`.
  static Set<String> interpretarEstandes(String bruto) {
    final texto = bruto.trim();
    if (texto.isEmpty) return const {};
    if (texto.startsWith('[')) {
      try {
        final lista = jsonDecode(texto);
        if (lista is List) {
          return lista.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toSet();
        }
      } catch (_) {
        // cai para o formato separado por vírgula
      }
    }
    return texto
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.replaceAll(RegExp(r'''[\[\]"']'''), '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}
