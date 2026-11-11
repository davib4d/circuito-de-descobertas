#!/usr/bin/env sh
# Gera o APK de release assinado e envia para o Firebase App Distribution.
#
# Uso:
#   FIREBASE_APP_ID="1:1234567890:android:abc123" TESTADORES="pessoa@exemplo.com" ./tools/distribuir.sh
#
# FIREBASE_APP_ID: Console do Firebase > Configurações do projeto > Seus apps > App Android > "ID do app".
# Requisitos: assinatura configurada (docs/android.md) e `firebase login` já feito.
set -e

: "${FIREBASE_APP_ID:?Defina FIREBASE_APP_ID com o ID do app Android no Firebase}"
: "${TESTADORES:?Defina TESTADORES com os e-mails separados por vírgula}"

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"

cd "$RAIZ/app"
flutter build apk --release

firebase appdistribution:distribute \
  "$RAIZ/app/build/app/outputs/flutter-apk/app-release.apk" \
  --app "$FIREBASE_APP_ID" \
  --testers "$TESTADORES" \
  --release-notes "Circuito de Descobertas: versão de teste da feira."
