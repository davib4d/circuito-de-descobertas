# Android: gerar a pasta nativa, assinar o APK e distribuir

A pasta `app/android/` não vem no repositório inicial porque é gerada pelo Flutter da sua máquina
(assim ela sai compatível com a sua versão do SDK, do Gradle e do AGP).

## 1. Gerar a pasta Android

```bash
cd app
flutter create . --platforms=android --org br.cesupa --project-name circuito_descobertas
flutter pub get
```

O comando só cria o que falta: `lib/`, `pubspec.yaml` e `test/` continuam como estão.
O identificador do app fica `br.cesupa.circuito_descobertas`. Depois de gerar, faça commit da pasta `android/`.

Se o build reclamar de versão mínima do Android, abra `app/android/app/build.gradle.kts` e troque
`minSdk = flutter.minSdkVersion` por `minSdk = 23`.

A permissão de câmera já vem declarada pelo pacote `mobile_scanner`; não precisa editar o `AndroidManifest.xml`.

## 2. Conectar ao Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android
```

Isso registra o app Android no projeto, baixa o `google-services.json`, aplica o plugin do Google
Services no Gradle e sobrescreve `lib/firebase_options.dart` com os dados reais.

## 3. Criar a chave de assinatura (uma vez)

```bash
keytool -genkey -v -keystore ~/circuito-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Crie `app/android/key.properties` (o `.gitignore` já impede que ele e o `.jks` sejam versionados):

```properties
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=upload
storeFile=/caminho/absoluto/para/circuito-upload.jks
```

## 4. Usar a chave no build de release

Em `app/android/app/build.gradle.kts`, adicione no topo do arquivo:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Dentro do bloco `android { ... }`, antes de `buildTypes`:

```kotlin
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
```

E em `buildTypes { release { ... } }` troque a linha `signingConfig = signingConfigs.getByName("debug")` por:

```kotlin
            signingConfig = signingConfigs.getByName("release")
```

## 5. Gerar e conferir o APK assinado

```bash
flutter build apk --release
```

Saída: `app/build/app/outputs/flutter-apk/app-release.apk`.

Para mostrar no vídeo que o APK está assinado com a sua chave (o `apksigner` fica em
`$ANDROID_HOME/build-tools/<versão>/`):

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

## 6. Enviar pelo Firebase App Distribution

Pelo console: **App Distribution → Versões → arraste o APK → adicione o e-mail do testador → Distribuir**.

Pela linha de comando, a partir da raiz do repositório:

```bash
FIREBASE_APP_ID="1:1234567890:android:abc123" TESTADORES="testador@exemplo.com" ./tools/distribuir.sh
```

O testador recebe um e-mail, aceita o convite no Android, baixa e instala a versão.
É preciso permitir a instalação de apps de fonte desconhecida para o navegador ou para o app Firebase App Tester.
