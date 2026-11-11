import 'package:cloud_firestore/cloud_firestore.dart';

class Estande {
  const Estande({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.localizacao,
    required this.ativo,
  });

  final String id;
  final String nome;
  final String descricao;
  final String localizacao;
  final bool ativo;

  factory Estande.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data() ?? const <String, dynamic>{};
    return Estande(
      id: doc.id,
      nome: (dados['nome'] as String?) ?? 'Estande ${doc.id}',
      descricao: (dados['descricao'] as String?) ?? '',
      localizacao: (dados['localizacao'] as String?) ?? '',
      ativo: (dados['ativo'] as bool?) ?? false,
    );
  }
}
