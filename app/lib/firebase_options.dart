// ARQUIVO PROVISÓRIO.
// Rode `flutterfire configure` dentro de app/ para gerar a versão real deste
// arquivo com os dados do seu projeto Firebase (ele será sobrescrito).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase ainda não configurado. Rode "flutterfire configure" na pasta app/.',
    );
  }
}
