// Prepara, verifica e compila o app Flutter do Circuito de Descobertas.
//
// Uso, a partir da raiz do repositório (só precisa do Flutter no PATH):
//
//   dart tools/preparar.dart          gera app/android/ (se faltar), baixa as
//                                     dependências, roda analyze e test
//   dart tools/preparar.dart apk      tudo acima + chave de assinatura (se
//                                     faltar) + APK de release assinado
//
// Pode rodar quantas vezes quiser: cada etapa só faz o que ainda falta.
// Detalhes de cada etapa: docs/android.md.
import 'dart:convert';
import 'dart:io';

const org = 'br.cesupa';
const nomeDoProjeto = 'circuito_descobertas';
const rotuloDoApp = 'Circuito de Descobertas';
const marcador = '// circuito: assinatura de release';

late final Directory app;

Future<void> main(List<String> args) async {
  final comando = args.isEmpty ? 'verificar' : args.first;
  if (!const {'verificar', 'apk'}.contains(comando)) {
    stderr.writeln('Uso: dart tools/preparar.dart [apk]');
    exit(64);
  }

  final raiz = File.fromUri(Platform.script).parent.parent;
  app = Directory('${raiz.path}/app');
  if (!File('${app.path}/pubspec.yaml').existsSync()) {
    falhar('Não achei app/pubspec.yaml em ${raiz.path}.');
  }

  etapa('Flutter');
  await rodar('flutter', ['--version']);

  etapa('Pasta Android');
  if (Directory('${app.path}/android').existsSync()) {
    print('app/android/ já existe; mantida.');
  } else {
    await rodar('flutter', [
      'create', '.',
      '--platforms=android',
      '--org', org,
      '--project-name', nomeDoProjeto,
    ]);
  }
  ajustarManifesto();
  ajustarGradle();

  etapa('Dependências');
  await rodar('flutter', ['pub', 'get']);

  etapa('Análise estática');
  await rodar('flutter', ['analyze']);

  etapa('Testes');
  await rodar('flutter', ['test']);

  if (comando == 'verificar') {
    etapa('Pronto');
    print('Código verificado. Próximos passos:');
    print('  1. flutterfire configure --platforms=android   (dentro de app/)');
    print('  2. dart tools/preparar.dart apk');
    return;
  }

  etapa('Firebase');
  exigirFirebase();

  etapa('Chave de assinatura');
  await garantirChave();

  etapa('APK de release');
  await rodar('flutter', ['build', 'apk', '--release']);
  final apk = File('${app.path}/build/app/outputs/flutter-apk/app-release.apk');
  await conferirAssinatura(apk);

  etapa('Pronto');
  print('APK assinado: ${apk.path}');
}

// ---------------------------------------------------------------- utilidades

void etapa(String titulo) => print('\n=== $titulo ===');

Never falhar(String mensagem) {
  stderr.writeln('\nERRO: $mensagem');
  exit(1);
}

void avisar(String mensagem) => print('AVISO: $mensagem');

/// Roda um comando dentro de app/ mostrando a saída; para tudo se falhar.
Future<void> rodar(String executavel, List<String> args) async {
  print('> $executavel ${args.join(' ')}');
  final Process processo;
  try {
    processo = await Process.start(
      executavel,
      args,
      workingDirectory: app.path,
      mode: ProcessStartMode.inheritStdio,
      // flutter e dart são arquivos .bat no Windows.
      runInShell: Platform.isWindows,
    );
  } on ProcessException {
    falhar('"$executavel" não foi encontrado no PATH.');
  }
  final codigo = await processo.exitCode;
  if (codigo != 0) {
    falhar('"$executavel ${args.join(' ')}" terminou com código $codigo. '
        'Corrija o que a saída acima aponta e rode o script de novo.');
  }
}

// ------------------------------------------------------- ajustes no Android

/// Nome exibido no Android e permissão de rede declarada no build de release.
void ajustarManifesto() {
  final arquivo = File('${app.path}/android/app/src/main/AndroidManifest.xml');
  if (!arquivo.existsSync()) {
    avisar('AndroidManifest.xml não encontrado; nada ajustado.');
    return;
  }
  var xml = arquivo.readAsStringSync();
  final original = xml;

  xml = xml.replaceFirst(
    'android:label="$nomeDoProjeto"',
    'android:label="$rotuloDoApp"',
  );

  if (!xml.contains('android.permission.INTERNET')) {
    xml = xml.replaceFirstMapped(
      RegExp(r'<manifest[^>]*>'),
      (m) => '${m[0]}\n'
          '    <uses-permission android:name="android.permission.INTERNET"/>',
    );
  }

  if (xml != original) {
    arquivo.writeAsStringSync(xml);
    print('AndroidManifest.xml ajustado (nome do app e permissão de rede).');
  }
}

/// Faz o build de release usar a chave de android/key.properties quando o
/// arquivo existir; sem ele, continua assinando com a chave de debug.
void ajustarGradle() {
  final arquivo = File('${app.path}/android/app/build.gradle.kts');
  if (!arquivo.existsSync()) {
    avisar('android/app/build.gradle.kts não encontrado. Configure a '
        'assinatura à mão seguindo docs/android.md.');
    return;
  }
  final original = arquivo.readAsStringSync();
  if (original.contains(marcador)) return;

  final nl = original.contains('\r\n') ? '\r\n' : '\n';
  var gradle = original.replaceAll('\r\n', '\n');

  const linhaDebug = 'signingConfig = signingConfigs.getByName("debug")';
  final blocoAndroid = RegExp(r'^android \{', multiLine: true);
  final blocoBuildTypes = RegExp(r'^( *)buildTypes \{', multiLine: true);

  if (!gradle.contains(linhaDebug) ||
      !blocoAndroid.hasMatch(gradle) ||
      !blocoBuildTypes.hasMatch(gradle)) {
    avisar('O build.gradle.kts gerado por esta versão do Flutter tem um '
        'formato que o script não reconhece. Configure a assinatura à mão '
        'seguindo docs/android.md.');
    return;
  }

  gradle = gradle.replaceFirst(blocoAndroid, '''
$marcador
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {''');

  gradle = gradle.replaceFirstMapped(blocoBuildTypes, (m) {
    final r = m[1]!;
    return '''
${r}signingConfigs {
$r    if (keystorePropertiesFile.exists()) {
$r        create("release") {
$r            keyAlias = keystoreProperties["keyAlias"] as String
$r            keyPassword = keystoreProperties["keyPassword"] as String
$r            storeFile = file(keystoreProperties["storeFile"] as String)
$r            storePassword = keystoreProperties["storePassword"] as String
$r        }
$r    }
$r}

${r}buildTypes {''';
  });

  gradle = gradle.replaceFirst(
    linhaDebug,
    'signingConfig = signingConfigs.getByName(\n'
        '                if (keystorePropertiesFile.exists()) "release" else "debug"\n'
        '            )',
  );

  gradle = 'import java.io.FileInputStream\nimport java.util.Properties\n\n$gradle';

  arquivo.writeAsStringSync(gradle.replaceAll('\n', nl));
  print('build.gradle.kts ajustado para assinar o release com key.properties.');
}

// ------------------------------------------------------------------ Firebase

void exigirFirebase() {
  final opcoes = File('${app.path}/lib/firebase_options.dart');
  final servicos = File('${app.path}/android/app/google-services.json');
  final provisorio =
      !opcoes.existsSync() || opcoes.readAsStringSync().contains('ARQUIVO PROVISÓRIO');

  if (provisorio || !servicos.existsSync()) {
    falhar('O app ainda não está ligado a um projeto Firebase. Dentro de app/, rode:\n'
        '  dart pub global activate flutterfire_cli\n'
        '  flutterfire configure --platforms=android\n'
        'e depois rode este script de novo.');
  }
  print('firebase_options.dart e google-services.json encontrados.');
}

// ---------------------------------------------------------------- assinatura

Future<void> garantirChave() async {
  final propriedades = File('${app.path}/android/key.properties');
  if (propriedades.existsSync()) {
    print('android/key.properties já existe; mantido.');
    return;
  }

  final keytool = await acharFerramentaJava('keytool');
  if (keytool == null) {
    falhar('Não achei o keytool (vem com o JDK / Android Studio). Crie a chave '
        'à mão seguindo docs/android.md e rode o script de novo.');
  }

  final senha = lerSenha();
  final chave = File('${app.path}/android/circuito-upload.jks');
  if (!chave.existsSync()) {
    final resultado = await Process.run(keytool, [
      '-genkeypair',
      '-keystore', chave.path,
      '-storetype', 'PKCS12',
      '-keyalg', 'RSA',
      '-keysize', '2048',
      '-validity', '10000',
      '-alias', 'upload',
      '-storepass', senha,
      '-keypass', senha,
      '-dname', 'CN=$rotuloDoApp, O=CESUPA, C=BR',
    ]);
    if (resultado.exitCode != 0) {
      falhar('keytool falhou:\n${resultado.stdout}${resultado.stderr}');
    }
    print('Chave criada em ${chave.path}');
  }

  // Barras normais: "\" é caractere de escape em arquivos .properties.
  final caminho = chave.absolute.path.replaceAll(r'\', '/');
  propriedades.writeAsStringSync(
    'storePassword=$senha\n'
    'keyPassword=$senha\n'
    'keyAlias=upload\n'
    'storeFile=$caminho\n',
  );
  print('android/key.properties criado. Ele e o .jks estão no .gitignore: '
      'guarde uma cópia dos dois e da senha fora do repositório.');
}

/// Senha da chave: variável CIRCUITO_SENHA_CHAVE ou digitada no terminal.
String lerSenha() {
  final doAmbiente = Platform.environment['CIRCUITO_SENHA_CHAVE'];
  if (doAmbiente != null) {
    if (!senhaValida(doAmbiente)) {
      falhar('CIRCUITO_SENHA_CHAVE precisa ter 6 a 64 letras ou números.');
    }
    return doAmbiente;
  }
  if (!stdin.hasTerminal) {
    falhar('Defina CIRCUITO_SENHA_CHAVE com a senha da chave de assinatura.');
  }
  while (true) {
    stdout.write('Crie uma senha para a chave de assinatura (6 a 64 letras ou números): ');
    stdin.echoMode = false;
    final String? digitada;
    try {
      digitada = stdin.readLineSync(encoding: utf8);
    } finally {
      stdin.echoMode = true;
    }
    stdout.writeln();
    if (digitada != null && senhaValida(digitada)) return digitada;
    print('Senha inválida.');
  }
}

bool senhaValida(String senha) => RegExp(r'^[A-Za-z0-9]{6,64}$').hasMatch(senha);

/// Procura keytool no PATH, no JAVA_HOME e no JDK que o Flutter usa.
Future<String?> acharFerramentaJava(String nome) async {
  final exe = Platform.isWindows ? '$nome.exe' : nome;
  final candidatos = <String>[exe];

  final javaHome = Platform.environment['JAVA_HOME'];
  if (javaHome != null && javaHome.isNotEmpty) candidatos.add('$javaHome/bin/$exe');

  try {
    final doctor = await Process.run(
      'flutter',
      ['doctor', '-v'],
      runInShell: Platform.isWindows,
      stdoutEncoding: utf8,
    );
    final java = RegExp(r'Java binary at: (.+)').firstMatch('${doctor.stdout}');
    if (java != null) {
      candidatos.add('${File(java[1]!.trim()).parent.path}/$exe');
    }
  } on ProcessException {
    // segue só com os candidatos anteriores
  }

  for (final candidato in candidatos) {
    try {
      final teste = await Process.run(candidato, ['-help']);
      if (teste.exitCode == 0) return candidato;
    } on ProcessException {
      // tenta o próximo
    }
  }
  return null;
}

/// Mostra o certificado do APK quando o apksigner do Android SDK está à mão.
Future<void> conferirAssinatura(File apk) async {
  if (!apk.existsSync()) falhar('O APK não apareceu em ${apk.path}.');

  final sdk = Platform.environment['ANDROID_HOME'] ?? Platform.environment['ANDROID_SDK_ROOT'];
  if (sdk == null) return;
  final ferramentas = Directory('$sdk/build-tools');
  if (!ferramentas.existsSync()) return;

  final versoes = ferramentas.listSync().whereType<Directory>().toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  for (final versao in versoes) {
    final apksigner = File('${versao.path}/apksigner${Platform.isWindows ? '.bat' : ''}');
    if (!apksigner.existsSync()) continue;
    final resultado = await Process.run(
      apksigner.path,
      ['verify', '--print-certs', apk.path],
      runInShell: Platform.isWindows,
    );
    stdout.write(resultado.stdout);
    return;
  }
}
