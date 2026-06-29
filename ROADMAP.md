# Project Oshiro — Revisão & Roadmap de Finalização

> Documento de retomada do projeto após período parado (último commit: set/2023).
> Objetivo definido: **portfólio / aprendizado**.

## 1. Propósito

App Flutter de **biblioteca de audiolivros**. Metadados em **Firestore**
(coleção `books`), áudios MP3 em **Firebase Storage** (`/books/{id}/audios/`).
O usuário **busca** (título/autor/ISBN + código de barras), **adiciona** livros
à biblioteca, **baixa** as faixas e **ouve** num player com controle de
velocidade/volume. Favoritos e estado local persistidos no device.

## 2. Dívidas técnicas catalogadas

### Bloqueadores (app não roda hoje)
- `lib/utils/firebase_options.dart` ausente (gitignorado) — não compila.
- Toolchain defasado: dependências de 2023 + Gradle 7.5 / AGP 7.3 contra
  Flutter 3.35 instalado.

### Estruturais
- Sem state management (setState em tudo), lógica de negócio dentro dos widgets.
- `book` é `dynamic` — sem models tipados; docs Firestore usados como mapas crus.
- **Dupla fonte de verdade**: arquivo `.txt` (FileManager) + SharedPreferences.
- Caminhos de MP3 salvos com chave só pelo nome do arquivo → **colisão entre
  livros** (duas faixas "01.mp3" se sobrescrevem).
- `getClientStream()` em `didChangeDependencies` → recarrega a coleção inteira
  repetidamente; filtragem 100% client-side.

### Bugs / funcionalidade
- Player placeholder: título/capa hardcoded, next/prev (`() => 0`) inertes,
  labels de velocidade incoerentes, sem retomar posição, sem background.
- Botão voltar da TrackList faz `push(HomePage)` em vez de `pop` → empilha telas.
- Drawer "Exibir em Lista" e "Excluir Livros" mortos; não há como **remover**
  livro/baixados.
- `flutter_barcode_scanner` abandonado.

### Qualidade / apresentação
- Sem testes reais (só boilerplate), sem CI, `applicationId = com.example.*`,
  README boilerplate, regras Firebase provavelmente abertas, `Image.network`
  sem tratamento de erro.

## 3. Decisões fechadas (stack-alvo)

| Eixo                | Decisão                                                              |
|---------------------|----------------------------------------------------------------------|
| Objetivo            | Portfólio / aprendizado                                              |
| Backend             | **Firebase real + modo mock** (flag)                                |
| Toolchain           | **Upgrade completo** p/ stable atual; `mobile_scanner` no scanner   |
| Arquitetura         | **Models + Repository + Riverpod**                                  |
| Persistência local  | **Isar (community)** — remove o `.txt`, escopo por livro            |
| Player              | **`just_audio` + `audio_service`** (playlist, retomar, background)  |
| Features extras     | Excluir/limpar downloads, loading/erro/vazio, toggle lista/grade, reordenar |
| Polimento           | README + screenshots, identidade do app, CI, regras Firebase        |
| Testes              | Unit (models/busca/repository c/ `fake_cloud_firestore`) + widget tests |

## 4. Roadmap em fases (ordem por dependência)

### Fase 0 — Destravar build & confirmar backend *(gate)*
- `flutterfire configure` → regenerar `firebase_options.dart`.
- **Confirmar que os dados existem** (coleção `books` + áudios no Storage). Se
  sumiram → o modo mock (Fase 1) vira o caminho de demonstração e/ou repovoa um
  seed mínimo.
- Subir Gradle → 8.x / AGP → 8.x; subir Firebase / audioplayers / dio; trocar
  o scanner abandonado por `mobile_scanner`.
- ✅ **Critério:** `flutter run` abre na Home listando livros (real ou mock).

### Fase 1 — Fundação de arquitetura
- Models `Book` / `Track`.
- `BookRepository` (Firestore) + `StorageRepository` (Storage/downloads), com
  flag de modo mock.
- Schema Isar + `LocalStore` tipado: remove o FileManager `.txt`, unifica a
  fonte de verdade, escopa estado por livro.
- Providers Riverpod (biblioteca / favoritos / busca).

### Fase 2 — Telas sobre a nova base
- Home consome providers (fim do recarregamento em `didChangeDependencies`).
- Search via repository + `mobile_scanner`.
- BookSelected e TrackList via repository; corrigir navegação (`pop`).

### Fase 3 — Player profissional *(destaque do portfólio)*
- Trocar `audioplayers` → `just_audio` + `audio_service`.
- Playlist por livro (next/prev reais), metadados reais (título/capa/faixa).
- Retomar posição por faixa (persistida no Isar).
- Background + controles na tela de bloqueio (config iOS/Android).
- Limpar controles decorativos (repeat, bookmark) e corrigir labels de velocidade.

### Fase 4 — Features secundárias
- Excluir livro / apagar downloads (drawer funcional).
- Toggle lista/grade.
- Reordenar biblioteca (drag & drop).
- Estados de loading/erro/vazio polidos + `errorBuilder` nas imagens.

### Fase 5 — Qualidade & apresentação
- Testes: unit (models, busca, repository com `fake_cloud_firestore`) + alguns
  widget tests das telas-chave.
- CI no GitHub Actions (`flutter analyze` + testes).
- Regras Firestore/Storage (leitura pública, escrita bloqueada).
- Identidade do app: `applicationId`/bundle próprio, nome e ícone definitivos.
- README com arquitetura, stack, como rodar (real + mock) e screenshots/gif.

## 5. Riscos a vigiar
- Config de background do `just_audio` / `audio_service` (mais chato no iOS).
- Codegen do Isar via `build_runner`.
- Existência dos dados no Firebase — é o gate da Fase 0.
