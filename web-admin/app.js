import { firebaseConfig } from "./firebase-config.js";
import { initializeApp } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js";
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";
import {
  getFirestore, collection, doc, getDoc, setDoc, updateDoc, onSnapshot, serverTimestamp, writeBatch,
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-firestore.js";

// Mesmo formato lido pelo app Flutter (lib/services/checkin_service.dart).
export const PREFIXO_QR = "circuito://estande/";
const ID_VALIDO = /^[A-Za-z0-9_-]{1,40}$/;

const $ = (id) => document.getElementById(id);
const telas = ["tela-carregando", "tela-config", "tela-login", "tela-sem-acesso", "tela-painel"];
function mostrarTela(id) {
  for (const t of telas) $(t).hidden = t !== id;
}

let avisoTimer;
function avisar(texto) {
  const el = $("aviso");
  el.textContent = texto;
  el.hidden = false;
  clearTimeout(avisoTimer);
  avisoTimer = setTimeout(() => { el.hidden = true; }, 3800);
}

async function copiar(texto, confirmacao) {
  try {
    await navigator.clipboard.writeText(texto);
    avisar(confirmacao);
  } catch {
    avisar("Não foi possível copiar. Selecione o texto e copie manualmente.");
  }
}

// ---------------------------------------------------------------- Inicialização
const configurado = firebaseConfig.apiKey && !firebaseConfig.apiKey.includes("COLE_AQUI");
if (!configurado) {
  mostrarTela("tela-config");
} else {
  iniciar();
}

function iniciar() {
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);

  /** @type {Map<string, {id:string,nome:string,descricao:string,localizacao:string,ativo:boolean}>} */
  let estandes = new Map();
  let contagens = new Map();        // estandeId -> total de check-ins
  let contagensAnteriores = new Map();
  let totalAnterior = 0;
  let visitantes = new Set();
  let selecaoMissao = new Set();
  let primeiraCargaCheckins = true;
  let cancelarEscutas = [];

  $("link-remote-config").href =
    `https://console.firebase.google.com/project/${firebaseConfig.projectId}/config`;

  // ------------------------------------------------------------ Autenticação
  onAuthStateChanged(auth, async (usuario) => {
    pararEscutas();
    if (!usuario || usuario.isAnonymous) {
      mostrarTela("tela-login");
      return;
    }
    mostrarTela("tela-carregando");
    try {
      const registro = await getDoc(doc(db, "admins", usuario.uid));
      if (!registro.exists()) {
        $("sem-acesso-uid").textContent = usuario.uid;
        mostrarTela("tela-sem-acesso");
        return;
      }
    } catch (erro) {
      console.error(erro);
      $("sem-acesso-uid").textContent = usuario.uid;
      mostrarTela("tela-sem-acesso");
      return;
    }
    $("conta-email").textContent = usuario.email ?? "";
    mostrarTela("tela-painel");
    escutarDados();
  });

  $("form-login").addEventListener("submit", async (evento) => {
    evento.preventDefault();
    const erro = $("login-erro");
    const botao = evento.submitter;
    erro.hidden = true;
    botao.disabled = true;
    try {
      await signInWithEmailAndPassword(auth, $("login-email").value.trim(), $("login-senha").value);
      $("login-senha").value = "";
    } catch (e) {
      erro.textContent = mensagemDeLogin(e.code);
      erro.hidden = false;
    } finally {
      botao.disabled = false;
    }
  });

  function mensagemDeLogin(codigo) {
    switch (codigo) {
      case "auth/invalid-email": return "Digite um e-mail válido.";
      case "auth/missing-password": return "Digite a senha.";
      case "auth/invalid-credential":
      case "auth/wrong-password":
      case "auth/user-not-found": return "E-mail ou senha incorretos.";
      case "auth/too-many-requests": return "Muitas tentativas. Aguarde um pouco e tente de novo.";
      case "auth/network-request-failed": return "Sem conexão com o Firebase. Verifique a internet.";
      case "auth/operation-not-allowed": return "Ative o login por e-mail e senha no Firebase Authentication.";
      default: return `Não foi possível entrar (${codigo}).`;
    }
  }

  const sair = () => signOut(auth);
  $("btn-sair").addEventListener("click", sair);
  $("btn-sair-sem-acesso").addEventListener("click", sair);
  $("btn-recarregar").addEventListener("click", () => location.reload());
  $("btn-copiar-uid").addEventListener("click", () =>
    copiar($("sem-acesso-uid").textContent, "UID copiado."));

  // ------------------------------------------------------------ Dados em tempo real
  function pararEscutas() {
    cancelarEscutas.forEach((cancelar) => cancelar());
    cancelarEscutas = [];
    primeiraCargaCheckins = true;
  }

  function escutarDados() {
    cancelarEscutas.push(onSnapshot(collection(db, "estandes"), (foto) => {
      estandes = new Map(foto.docs.map((d) => [d.id, { id: d.id, ...d.data() }]));
      desenhar();
    }, falhaDeLeitura));

    // O total por estande é sempre recalculado a partir dos documentos de check-in.
    cancelarEscutas.push(onSnapshot(collection(db, "checkins"), (foto) => {
      const novas = new Map();
      const pessoas = new Set();
      foto.forEach((d) => {
        const { estandeId, visitanteId } = d.data();
        novas.set(estandeId, (novas.get(estandeId) ?? 0) + 1);
        pessoas.add(visitanteId);
      });
      if (!primeiraCargaCheckins) {
        for (const mudanca of foto.docChanges()) {
          if (mudanca.type !== "added") continue;
          const estande = estandes.get(mudanca.doc.data().estandeId);
          avisar(`Novo check-in em ${estande?.nome ?? mudanca.doc.data().estandeId}`);
        }
      }
      contagens = novas;
      visitantes = pessoas;
      desenhar();
      primeiraCargaCheckins = false;
    }, falhaDeLeitura));
  }

  function falhaDeLeitura(erro) {
    console.error(erro);
    avisar(erro.code === "permission-denied"
      ? "Leitura negada pelas regras do Firestore. Publique o arquivo firestore.rules."
      : "Falha ao ler o Firestore. Verifique a conexão.");
  }

  // ------------------------------------------------------------ Desenho
  function ordenados() {
    return [...estandes.values()].sort((a, b) => a.id.localeCompare(b.id, "pt-BR", { numeric: true }));
  }

  function el(tag, classe, texto) {
    const no = document.createElement(tag);
    if (classe) no.className = classe;
    if (texto !== undefined) no.textContent = texto;
    return no;
  }

  function desenhar() {
    const lista = $("lista-estandes");
    const itens = ordenados();
    lista.replaceChildren(...itens.map(cartaoDeEstande));
    $("vazio").hidden = itens.length > 0;

    const total = [...contagens.values()].reduce((soma, n) => soma + n, 0);
    const placar = $("total-checkins");
    placar.textContent = total;
    if (!primeiraCargaCheckins && total > totalAnterior) destacar(placar);
    totalAnterior = total;

    $("total-estandes").textContent = itens.length;
    $("total-ativos").textContent = itens.filter((e) => e.ativo).length;
    $("total-visitantes").textContent = visitantes.size;

    contagensAnteriores = new Map(contagens);
    desenharMissao(itens);
  }

  function destacar(no) {
    no.classList.remove("subiu");
    void no.offsetWidth; // reinicia a animação
    no.classList.add("subiu");
  }

  function cartaoDeEstande(estande) {
    const total = contagens.get(estande.id) ?? 0;
    const cartao = el("article", estande.ativo ? "estande" : "estande inativo");

    cartao.append(el("div", "miniatura", estande.id));

    const dados = el("div", "dados");
    dados.append(
      el("h2", "", estande.nome),
      el("p", "local", estande.localizacao),
      el("p", "descricao", estande.descricao || "Sem descrição."),
      el("span", "estado", estande.ativo ? "Ativo" : "Inativo"),
    );

    const lado = el("div", "lado");
    const contagem = el("div", "contagem");
    const numero = el("strong", "", String(total));
    if (!primeiraCargaCheckins && total > (contagensAnteriores.get(estande.id) ?? 0)) {
      numero.classList.add("subiu");
    }
    contagem.append(numero, el("span", "", total === 1 ? "check-in" : "check-ins"));

    const botoes = el("div", "botoes");
    const btnQr = el("button", "botao lilas pequeno", "Ver QR code");
    btnQr.type = "button";
    btnQr.addEventListener("click", () => abrirQr(estande));
    const btnEditar = el("button", "botao fantasma pequeno", "Editar");
    btnEditar.type = "button";
    btnEditar.addEventListener("click", () => abrirFormulario(estande));
    botoes.append(btnQr, btnEditar);

    lado.append(contagem, botoes);
    cartao.append(dados, lado);
    return cartao;
  }

  // ------------------------------------------------------------ Apoio à missão
  function desenharMissao(itens) {
    const ativos = itens.filter((e) => e.ativo);
    selecaoMissao = new Set([...selecaoMissao].filter((id) => ativos.some((e) => e.id === id)));

    $("missao-chips").replaceChildren(...ativos.map((estande) => {
      const chip = el("button", "chip", estande.id);
      chip.type = "button";
      chip.title = estande.nome;
      chip.setAttribute("aria-pressed", String(selecaoMissao.has(estande.id)));
      chip.addEventListener("click", () => {
        if (selecaoMissao.has(estande.id)) selecaoMissao.delete(estande.id);
        else selecaoMissao.add(estande.id);
        desenharMissao(ordenados());
      });
      return chip;
    }));
    $("missao-valor").textContent = [...selecaoMissao].join(",") || "—";
  }

  $("btn-copiar-missao").addEventListener("click", () => {
    if (selecaoMissao.size === 0) {
      avisar("Marque ao menos um estande ativo.");
      return;
    }
    copiar([...selecaoMissao].join(","), "Valor copiado. Cole em missao_estandes no Remote Config.");
  });

  // ------------------------------------------------------------ Cadastro e edição
  const dlgEstande = $("dlg-estande");
  let emEdicao = null;

  function proximoId() {
    let maior = 0;
    for (const id of estandes.keys()) {
      const achado = /^E(\d+)$/.exec(id);
      if (achado) maior = Math.max(maior, Number(achado[1]));
    }
    return `E${String(maior + 1).padStart(2, "0")}`;
  }

  function abrirFormulario(estande) {
    emEdicao = estande ?? null;
    $("dlg-estande-titulo").textContent = estande ? "Editar estande" : "Cadastrar estande";
    $("campo-id").value = estande ? estande.id : proximoId();
    $("campo-id").readOnly = Boolean(estande);
    $("campo-nome").value = estande?.nome ?? "";
    $("campo-descricao").value = estande?.descricao ?? "";
    $("campo-localizacao").value = estande?.localizacao ?? "";
    $("campo-ativo").checked = estande ? estande.ativo : true;
    $("form-erro").hidden = true;
    dlgEstande.showModal();
    $("campo-nome").focus();
  }

  $("btn-novo").addEventListener("click", () => abrirFormulario());
  $("btn-cancelar-estande").addEventListener("click", () => dlgEstande.close());

  $("form-estande").addEventListener("submit", async (evento) => {
    evento.preventDefault();
    const erro = $("form-erro");
    const falhar = (texto) => { erro.textContent = texto; erro.hidden = false; };
    erro.hidden = true;

    const id = $("campo-id").value.trim();
    const dados = {
      nome: $("campo-nome").value.trim(),
      descricao: $("campo-descricao").value.trim(),
      localizacao: $("campo-localizacao").value.trim(),
      ativo: $("campo-ativo").checked,
    };
    if (!ID_VALIDO.test(id)) return falhar("O identificador aceita letras, números, hífen e sublinhado (até 40 caracteres).");
    if (!dados.nome) return falhar("Informe o nome do estande.");
    if (!dados.localizacao) return falhar("Informe a localização do estande.");

    const botao = $("btn-salvar-estande");
    botao.disabled = true;
    try {
      const ref = doc(db, "estandes", id);
      if (emEdicao) {
        await updateDoc(ref, { ...dados, atualizadoEm: serverTimestamp() });
        avisar("Estande atualizado.");
      } else {
        if ((await getDoc(ref)).exists()) {
          falhar(`Já existe um estande com o identificador ${id}.`);
          return;
        }
        await setDoc(ref, { ...dados, criadoEm: serverTimestamp(), atualizadoEm: serverTimestamp() });
        avisar("Estande cadastrado. Ele já aparece no app.");
      }
      dlgEstande.close();
    } catch (e) {
      console.error(e);
      falhar(e.code === "permission-denied"
        ? "As regras do Firestore negaram a gravação. Confira se esta conta está em /admins."
        : "Não foi possível salvar. Verifique a conexão e tente de novo.");
    } finally {
      botao.disabled = false;
    }
  });

  $("btn-exemplos").addEventListener("click", async (evento) => {
    const botao = evento.currentTarget;
    botao.disabled = true;
    const exemplos = [
      ["E01", "Maré Viva", "Sensores de baixo custo que avisam ribeirinhos sobre a subida da maré.", "Corredor A, estande 4"],
      ["E02", "Tacacá Tech", "Cardápio digital com pedidos por voz para barracas de comida regional.", "Corredor C, estande 11"],
      ["E03", "Rota do Açaí", "Rastreio da cadeia do açaí, do batedor até a entrega.", "Corredor D, estande 2"],
    ];
    try {
      const lote = writeBatch(db);
      for (const [id, nome, descricao, localizacao] of exemplos) {
        lote.set(doc(db, "estandes", id), {
          nome, descricao, localizacao, ativo: true,
          criadoEm: serverTimestamp(), atualizadoEm: serverTimestamp(),
        });
      }
      await lote.commit();
      avisar("Três estandes de exemplo criados.");
    } catch (e) {
      console.error(e);
      avisar("Não foi possível criar os exemplos. Confira as regras do Firestore.");
    } finally {
      botao.disabled = false;
    }
  });

  // ------------------------------------------------------------ QR code
  const dlgQr = $("dlg-qr");

  function abrirQr(estande) {
    const qr = qrcode(0, "M");
    qr.addData(PREFIXO_QR + estande.id);
    qr.make();
    $("qr-figura").innerHTML = qr.createSvgTag({ cellSize: 8, margin: 2, scalable: true });
    $("qr-nome").textContent = estande.nome;
    $("qr-local").textContent = estande.localizacao;
    $("qr-id").textContent = `Identificador ${estande.id}`;

    const parametros = new URLSearchParams({ id: estande.id, nome: estande.nome, local: estande.localizacao });
    $("qr-abrir").href = `qr.html?${parametros}`;
    $("qr-imprimir").href = `qr.html?${parametros}&imprimir=1`;
    dlgQr.showModal();
  }

  $("btn-fechar-qr").addEventListener("click", () => dlgQr.close());
  for (const dialogo of [dlgEstande, dlgQr]) {
    dialogo.addEventListener("click", (evento) => {
      if (evento.target === dialogo) dialogo.close(); // clique fora fecha
    });
  }
}
