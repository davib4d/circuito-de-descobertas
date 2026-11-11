# Android: gerar a pasta nativa, assinar o APK e distribuir

A pasta `app/android/` não vem no repositório inicial porque é gerada pelo Flutter da sua máquina
(assim ela sai compatível com a sua versão do SDK, do Gradle e do AGP).

O script `tools/preparar.dart` automatiza as etapas 1, 3 e 4 abaixo. Ele só precisa do Flutter no PATH,
funciona em Windows, Linux e macOS e pode ser rodado quantas vezes for preciso (cada etapa só faz o que
ainda falta):

```bash
dart tools/preparar.dart        # gera android/, pub get, analyze, test
dart tools/preparar.dart apk    # tudo acima + chave de assinatura + APK de release
```

## 1. Gerar a pasta Android e verificar o código

```bash
dart tools/preparar.dart
```

O que o script faz, dentro de `app/`:

1. `flutter create . --platforms=android --org br.cesupa --project-name circuito_descobertas`, se
   `android/` ainda não existir. O comando só cria o que falta: `lib/`, `pubspec.yaml` e `test/`
   continuam como estão. O identificador do app fica `br.cesupa.circuito_descobertas`.
2. Ajusta o `AndroidManifest.xml`: nome exibido “Circuito de Descobertas” e permissão `INTERNET`
   declarada também no build de release.
3. Ajusta o `android/app/build.gradle.kts` para assinar o release com `android/key.properties`
   quando o arquivo existir (sem ele, o build continua usando a chave de debug).
4. `flutter pub get`, `flutter analyze` e `flutter test`.

Depois de gerar, faça commit da pasta `android/`.

Se o build reclamar de versão mínima do Android, abra `app/android/app/build.gradle.kts` e troque
`minSdk = flutter.minSdkVersion` por `minSdk = 23`.

A permissão de câmera já vem declarada pelo pacote `mobile_scanner`.

## 2. Conectar ao Firebase

```bash
cd app
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android
```

Isso registra o app Android no projeto, baixa o `google-services.json`, aplica o plugin do Google
Services no Gradle e sobrescreve `lib/firebase_options.dart` com os dados reais.

## 3. Chave de assinatura

```bash
dart tools/preparar.dart apk
```

Na primeira vez o script pede uma senha (ou lê a variável `CIRCUITO_SENHA_CHAVE`), cria a chave em
`app/android/circuito-upload.jks` e grava `app/android/key.properties`. O `.gitignore` impede que os
dois sejam versionados: guarde uma cópia deles e da senha em lugar seguro, porque toda atualização
do app precisa ser assinada com a mesma chave.

Para criar à mão, se preferir:

```bash
keytool -genkeypair -v -keystore app/android/circuito-upload.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

E o `app/android/key.properties` (use `/` no caminho, mesmo no Windows):

```properties
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=upload
storeFile=/caminho/absoluto/para/circuito-upload.jks
```

## 4. Gerar e conferir o APK assinado

O mesmo `dart tools/preparar.dart apk` confere se o Firebase já foi configurado, roda
`flutter build apk --release` e, se `ANDROID_HOME` estiver definido, imprime o certificado do APK.

Saída: `app/build/app/outputs/flutter-apk/app-release.apk`.

Para conferir a assinatura à mão (o `apksigner` fica em `$ANDROID_HOME/build-tools/<versão>/`):

```bash
apksigner verify --print-certs app/build/app/outputs/flutter-apk/app-release.apk
```

## 5. Enviar pelo Firebase App Distribution

Pelo console: **App Distribution → Versões → arraste o APK → adicione o e-mail do testador → Distribuir**.

Pela linha de comando, a partir da raiz do repositório (em Windows, use o Git Bash):

```bash
FIREBASE_APP_ID="1:1234567890:android:abc123" TESTADORES="testador@exemplo.com" ./tools/distribuir.sh
```

O testador recebe um e-mail, aceita o convite no Android, baixa e instala a versão.
É preciso permitir a instalação de apps de fonte desconhecida para o navegador ou para o app Firebase App Tester.

## Se o script não reconhecer o `build.gradle.kts`

Versões futuras do Flutter podem gerar o arquivo com outro formato; nesse caso o script avisa e não
altera nada. Faça o ajuste à mão em `app/android/app/build.gradle.kts`.

No topo do arquivo:

```kotlin
import java.io.FileInputStream
import java.util.Properties
```

Logo antes de `android {`:

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Dentro de `android { ... }`, antes de `buildTypes`:

```kotlin
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
```

E em `buildTypes { release { ... } }` troque `signingConfig = signingConfigs.getByName("debug")` por:

```kotlin
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug"
            )
```
