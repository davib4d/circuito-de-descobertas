# Circuito de Descobertas

Sistema para incentivar a circulação de visitantes no Amazon Hacking: a organização cadastra estandes e
lança uma missão surpresa; os visitantes recebem a missão no app e registram a visita lendo o QR code do estande.

Atividade prática de Laboratório de Programação Mobile (CESUPA).

| Parte | Tecnologia | Pasta |
|---|---|---|
| Painel web da organização | HTML, CSS e JavaScript (SDK web do Firebase por CDN, sem build) | `web-admin/` |
| App do visitante | Flutter (Android) | `app/` |
| Dados e acesso | Cloud Firestore e Firebase Authentication | `firestore.rules` |
| Missão surpresa | Firebase Remote Config com atualização em tempo real | `remoteconfig.template.json` |
| Medição | Google Analytics para Firebase (GA4) | `app/lib/services/analytics_service.dart` |
| Distribuição | Firebase App Distribution | `tools/distribuir.sh` |

Tudo funciona no plano Spark, sem cartão.

## Como os dados estão organizados

```
estandes/{estandeId}            estandeId legível, ex.: E01
  nome, descricao, localizacao, ativo, criadoEm, atualizadoEm

checkins/{visitanteId}_{estandeId}
  visitanteId, estandeId, criadoEm

admins/{uid}                    criado à mão no console; define quem é administrador
```

- O QR code de cada estande contém `circuito://estande/<estandeId>`.
- O ID do check-in é a chave composta `visitante_estande`. Regravar o mesmo documento seria um `update`,
  que as regras negam; por isso não existe visita duplicada, nem com dois toques simultâneos.
- O total por estande no painel é contado a partir dos documentos de `checkins`, em tempo real.

### Regras de acesso (`firestore.rules`)

| Quem | Pode |
|---|---|
| Administrador (tem documento em `admins/`) | criar e editar estandes, ler todos os estandes e todos os check-ins |
| Visitante (sessão anônima) | listar estandes ativos, criar check-in da própria identidade em estande ativo, ler os próprios check-ins |
| Ninguém | apagar estandes, alterar ou apagar check-ins, escrever em `admins/` |

Um visitante que lê o QR de um estande inativo recebe `permission-denied` na leitura; o app traduz isso
como “Estande inativo”. Um ID que não existe volta como documento inexistente: “QR code inválido”.

### Parâmetros do Remote Config

| Parâmetro | Tipo | Padrão local no app | Uso |
|---|---|---|---|
| `missao_ativa` | Booleano | `false` | liga e desliga a missão |
| `missao_estandes` | String | vazio | IDs em destaque: `E01,E03` (também aceita `["E01","E03"]`) |
| `missao_titulo` | String | `Missão surpresa` | título da chamada (opcional) |
| `missao_descricao` | String | texto padrão | texto de apoio (opcional) |

### Eventos do Analytics

| Evento | Quando | Parâmetros |
|---|---|---|
| `missao_aberta` | o visitante abre a tela da missão | `qtd_estandes` |
| `checkin_concluido` | depois que o check-in foi gravado no Firestore | `estande_id`, `em_missao` |

## Passo a passo

Pré-requisitos: Flutter 3.29 ou mais novo, Node.js (para a Firebase CLI) e um celular Android.

### 1. Projeto no Firebase

1. Crie o projeto em <https://console.firebase.google.com> **com o Google Analytics ativado**.
2. **Authentication → Método de login**: ative **E-mail/senha** e **Anônimo**.
3. **Firestore Database → Criar banco de dados** (modo de produção, qualquer região).
4. Instale a CLI e selecione o projeto:

```bash
npm install -g firebase-tools
firebase login
firebase use --add
```

### 2. Regras do Firestore

```bash
firebase deploy --only firestore:rules
```

### 3. Administrador

1. **Authentication → Usuários → Adicionar usuário**: crie o e-mail e a senha da organização.
2. Copie o **UID** desse usuário.
3. **Firestore → Iniciar coleção** `admins` → ID do documento = o UID copiado → um campo qualquer, por exemplo `nome: "Organização"`.

Se você entrar no painel antes de fazer o item 3, ele mostra o UID e o que falta.

### 4. Painel web

1. **Configurações do projeto → Seus apps → Web (`</>`)**: registre um app e copie a configuração.
2. Cole em `web-admin/firebase-config.js`.
3. Rode localmente:

```bash
npx serve web-admin
```

Ou publique no Firebase Hosting (gratuito):

```bash
firebase deploy --only hosting
```

No painel vazio há um botão **Criar 3 estandes de exemplo** (E01, E02 e E03).

### 5. App Flutter

Siga `docs/android.md` (gera a pasta `android/`, roda o `flutterfire configure` e configura a assinatura). Resumo:

```bash
cd app
flutter create . --platforms=android --org br.cesupa --project-name circuito_descobertas
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android
flutter test
flutter run
```

### 6. Remote Config

Opção A, pela CLI (**sobrescreve** o modelo que estiver publicado no projeto):

```bash
firebase deploy --only remoteconfig
```

Opção B, pelo console: **Remote Config → Criar configuração** e adicione os parâmetros da tabela acima.

Para a demonstração: mude `missao_ativa` para `true`, ajuste `missao_estandes` e clique em **Publicar alterações**.
O app aberto recebe a mudança em poucos segundos, sem reiniciar. No painel web, o bloco “Missão surpresa”
monta o valor de `missao_estandes` para você copiar.

### 7. APK assinado e App Distribution

Passos 3 a 6 de `docs/android.md`.

### 8. Analytics

Os eventos saem do app instalado normalmente. Abra **Analytics → Relatórios → Tempo real**; no cartão
**Contagem de eventos por Nome do evento** aparecem `missao_aberta` e `checkin_concluido`. Clique em
`checkin_concluido` → `estande_id` para ver o valor (ex.: `E03`).

Os eventos podem levar de alguns segundos a alguns minutos. Só para testar mais rápido antes de gravar,
dá para ativar o modo de depuração e acompanhar pelo **DebugView**:

```bash
adb shell setprop debug.firebase.analytics.app br.cesupa.circuito_descobertas
# para desligar:
adb shell setprop debug.firebase.analytics.app .none.
```

## Roteiro do vídeo

1. **App Distribution (1,0)**: apresente os integrantes. Mostre o APK assinado, o envio no console, o convite
   chegando no Android, a instalação e o app abrindo.
2. **Painel + app**: cadastre um estande no painel e mostre que ele aparece no app sem recarregar. Abra o QR code.
3. **Remote Config (1,0)**: com o app aberto e a missão desligada, publique `missao_ativa = true`. A chamada e os
   destaques aparecem no mesmo app. Abra a missão, leia o QR code, mostre o total subindo no painel.
   Publique `missao_ativa = false` e mostre a chamada sumindo; a lista e o check-in continuam funcionando.
4. **Analytics (1,0)**: no Tempo real do GA4, mostre `missao_aberta` e `checkin_concluido` e abra o
   `estande_id` do check-in.
5. **Demonstração integrada (0,5)**: os itens 2 a 4 em sequência já fecham o percurso completo.

Vale mostrar também os retornos do leitor: ler o mesmo QR de novo (“Visita já registrada”), desativar um estande
no painel e ler o QR dele (“Estande inativo”) e ler um QR qualquer (“QR code inválido”).

## Onde cada requisito da lauda está

| Requisito | Onde |
|---|---|
| Autenticar administrador | `web-admin/app.js` (login por e-mail e senha + checagem em `admins/`) |
| Cadastrar e editar estandes (nome, descrição, localização, ativo) | `web-admin/app.js`, diálogo “Cadastrar estande” |
| QR code por estande, abrir em outra tela ou imprimir | `web-admin/qr.html` |
| Total de check-ins por estande em tempo real | `web-admin/app.js`, `escutarDados()` |
| Listar estandes ativos com a missão desligada | `app/lib/screens/home_screen.dart` |
| Ler QR, validar e dar retorno (inválido, inativo, já registrado, sucesso) | `app/lib/services/checkin_service.dart`, `app/lib/widgets/resultado_sheet.dart` |
| Uma visita por estande e por visitante | chave composta em `checkin_service.dart` + `firestore.rules` |
| Missão por Remote Config, padrão local desligado, tempo real | `app/lib/services/missao_service.dart` |
| Chamada, destaques e tela da missão | `home_screen.dart`, `missao_screen.dart` |
| Regras de acesso | `firestore.rules` |
| Eventos `missao_aberta` e `checkin_concluido` com `estande_id` | `app/lib/services/analytics_service.dart` |

## Identidade visual

Baseada na referência da equipe: céu em degradê lilás com nuvens menta, títulos em Montserrat, campos e
botões em pílula, cartões brancos sobre um bloco menta e um único ponto coral para a ação principal
(“Ler QR code” no app, “Cadastrar estande” no painel). As cores ficam em `app/lib/theme/app_theme.dart`
e no topo de `web-admin/styles.css`.

![Prévia do painel web com dados de exemplo](docs/painel-previa.png)
