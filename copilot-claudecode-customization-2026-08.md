# GitHub Copilot / Claude Code カスタマイズファイル 完全整理（2026-08-29 時点）

## 0. 全体像：7 つのレイヤー

| レイヤー | 役割 | Copilot | Claude Code |
|---|---|---|---|
| 常時ロード指示 | プロジェクト全体の前提・規約 | `.github/copilot-instructions.md` / `AGENTS.md` / `CLAUDE.md` | `CLAUDE.md` / `CLAUDE.local.md` / `.claude/rules/*.md`（paths なし） |
| 条件付きロード指示 | ファイル種別・ディレクトリ単位の規約 | `.github/instructions/*.instructions.md`（`applyTo`） | `.claude/rules/*.md`（`paths`） |
| 手動呼び出しプロンプト | `/name` で叩く定型タスク | `.github/prompts/*.prompt.md` | `.claude/commands/*.md`（skill に統合済み） |
| オンデマンド手順書 | モデルが自動判断でロードする手順＋付随ファイル | `.github/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` |
| 役割（ペルソナ）定義 | ツール制限・モデル指定を持つ別コンテキスト | `.github/agents/*.agent.md` | `.claude/agents/*.md`（サブエージェント） |
| 決定的実行 | モデルの判断に依らず必ず走る | `.github/hooks/*.json` | `settings.json` の `hooks` / permissions |
| 外部接続・配布 | MCP・プラグイン | MCP 設定 / Agent Plugins（`plugin.json`） | `.mcp.json` / plugins |

指示（instructions / CLAUDE.md）は「モデルへの助言」であり強制ではない。強制したい規則は Copilot は hooks、Claude Code は hooks / permissions に置く。これは両者の公式ドキュメントが明示している設計思想。

---

## 1. GitHub Copilot 側の定義ファイル

### 1-1. `.github/copilot-instructions.md`（常時ロード・リポジトリ単位）

- 置き場所はリポジトリルートの `.github/` 直下のみ。他パスは認識されない。
- 全チャットリクエストに自動付与。VS Code / Visual Studio / GitHub.com で共通。
- インライン補完（ゴーストテキスト）には効かない。
- VS Code 設定 `github.copilot.chat.codeGeneration.useInstructionFiles` を true に。
- `/init` で既存の慣習（`AGENTS.md`、Cursor ルール等）を読み取って自動生成できる。

### 1-2. `AGENTS.md`（クロスツール標準）

- ワークスペースルートに置くと常時ロード。設定キー `chat.useAgentsMdFile`。
- **サブフォルダ配置は実験的機能**：`chat.useNestedAgentsMdFiles` を有効にすると、ワークスペース配下を再帰探索し「相対パス付き」でチャットコンテキストに載る。中身を全部読み込むのではなく、エージェントが編集対象に応じてどれを使うか判断する方式。
- Copilot / Claude Code / Cursor / Codex が読む「共通言語」だが、**Claude Code だけは AGENTS.md を直接読まない**（後述）。

### 1-3. `CLAUDE.md`（VS Code 側の互換読み込み）

- VS Code は `CLAUDE.md` も常時ロード指示として検出する。設定キー `chat.useClaudeMdFile`。
- 探索先：ワークスペースルート `CLAUDE.md`、`.claude/CLAUDE.md`、`~/.claude/CLAUDE.md`、`CLAUDE.local.md`。

### 1-4. `*.instructions.md`（条件付きロード）

| スコープ | 既定パス |
|---|---|
| ワークスペース | `.github/instructions/` |
| ワークスペース（Claude 形式） | `.claude/rules/` |
| ユーザー | `~/.copilot/instructions` または `~/.claude/rules` |

- 追加パスは `chat.instructionsFilesLocations` で設定（各パスを true/false で個別に有効化）。
- **フォルダは再帰探索される**。`.github/instructions/frontend/react.instructions.md` のようなサブディレクトリ整理が可能。ただし「どこに置いたか」は適用条件に影響せず、適用は frontmatter の `applyTo` グロブだけで決まる。
- frontmatter：`name`（表示名）、`description`、`applyTo`（グロブ。未指定なら自動適用されず手動添付のみ）。
- 本文からツール参照は `#tool:<tool-name>`。
- `.claude/rules` に置く場合は `applyTo` ではなく Claude 形式の `paths`（配列、省略時 `**`）を使う。
- 複数ファイルがマッチすると全部が同時にコンテキストへ積まれる（優先順位による排他ではない）。

```markdown
---
name: 'Java standards'
description: 'サーバサイド Java の規約'
applyTo: '**/*.java'
---
- 例外は握り潰さずログにコンテキストを含めて出す
- DTO は record、可変フィールドを持たせない
```

### 1-5. `*.prompt.md`（手動呼び出し／スラッシュコマンド）

- 既定パス：ワークスペース `.github/prompts/`、ユーザーは VS Code プロファイル内。追加は `chat.promptFilesLocations`。
- frontmatter：`description` / `name` / `argument-hint` / `agent`（`ask`・`agent`・`plan`・カスタムエージェント名）/ `model` / `tools`。
- 本文で `${input:変数名}`、Markdown リンクによる instructions 参照、`#tool:` 参照が使える。
- **重要な制約**：Agent Host 上で動くエージェントは prompt ファイルを読まない。Agent Customizations エディタに prompt → skill への移行機能あり（`chat.customizations.promptMigration.enabled`）。新規は skill で作る方が将来安全。

### 1-6. `*.agent.md`（カスタムエージェント＝旧カスタムチャットモード）

| スコープ | 既定パス |
|---|---|
| ワークスペース | `.github/agents/` |
| ワークスペース（Claude 形式） | `.claude/agents/` |
| ユーザー | `~/.copilot/agents` |

- 追加パスは `chat.agentFilesLocations`。`.github/agents` 配下は `.md` でも検出される。
- 旧 `.chatmode.md` は `.agent.md` にリネームして移行。
- frontmatter：`name` / `description` / `argument-hint` / `tools` / `agents`（サブエージェント許可リスト、`*` or `[]`）/ `model`（配列でフォールバック順）/ `user-invocable` / `disable-model-invocation` / `target`（`vscode` or `github-copilot`）/ `mcp-servers` / `handoffs`（`label`・`agent`・`prompt`・`send`・`model`）/ `hooks`（プレビュー、`chat.useCustomAgentHooks`）。
- `.claude/agents` 側は Claude 形式 frontmatter（`name` 必須、`description`、`tools` はカンマ区切り文字列、`disallowedTools`）で、VS Code が Claude のツール名をマッピングする。
- 組織レベル定義は `github.copilot.chat.organizationCustomAgents.enabled` で検出。

### 1-7. `SKILL.md`（Agent Skills／オープン標準）

| スコープ | パス |
|---|---|
| プロジェクト | `.github/skills/<name>/`、`.claude/skills/<name>/`、`.agents/skills/<name>/` |
| 個人 | `~/.copilot/skills/`、`~/.agents/skills/` |

- 「指示＋スクリプト＋参照資料」をフォルダごとパッケージ化したもの。description のマッチでモデルが必要時にだけ本体をロード（プログレッシブディスクロージャ）。
- 動作範囲：Copilot cloud agent、code review、Copilot CLI、Copilot アプリ、VS Code / JetBrains のエージェントモード。
- `/` メニューにも並び、`/skill-name 追加指示` の形で明示呼び出しも可能。
- CLI 管理：`gh skill`（preview / install / update / validate --dry-run / --fix）。インストール時に取得元リポジトリ・ref・tree SHA が frontmatter に provenance として書かれる。
- 公式コレクション：`github/awesome-copilot`、`anthropics/skills`。
- **Copilot と Claude Code が同じ `.claude/skills/` を読めるため、実質ここが両ツール共通の資産置き場になる。**

### 1-8. `.github/hooks/*.json`（決定的フック／プレビュー）

- ワークスペース `.github/hooks/*.json`（フォルダ内の `.json` を自動ロード）、Claude 互換として `.claude/settings.json` / `.claude/settings.local.json`、ユーザーは `~/.copilot/hooks/`、エージェント個別は `.agent.md` の `hooks` フィールド、プラグインは `com.github.copilot/hooks/hooks.json`。
- イベント（8種）：`SessionStart` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `PreCompact` / `SubagentStart` / `SubagentStop` / `Stop`。
- `type` は `command` のみ。stdin に JSON が渡り、stdout の JSON で `additionalContext` 注入や許可/ブロックを返す。アクセス制御の判断ができるのは `PreToolUse` のみ、他は観測用。
- VS Code 側の注意：matcher（`"Edit|Write"` など）はパースされるが**適用されない**。マッチャに関係なく全イベントで実行される。
- Copilot cloud agent で使うには、hooks の JSON がリポジトリの**デフォルトブランチ**に存在する必要がある。
- ログは Output パネルの「GitHub Copilot Chat Hooks」チャネル。

### 1-9. Agent Plugins（配布パッケージ）

```
my-plugin/
├── plugin.json                 # メタデータ
├── skills/<name>/SKILL.md      # スキル＋付随スクリプト
├── mcp.json                    # MCP サーバ定義
├── scripts/                    # フック用スクリプト
└── com.github.copilot/         # Copilot 固有名前空間
    ├── agents/*.agent.md
    └── hooks/hooks.json
```

- VS Code は `com.github.copilot` 名前空間だけ読み、他クライアント所有の名前空間は無視する。Claude 形式プラグインも同等機能を別パスで提供。
- プラグインを無効化すると、そこ由来の skills / agents / hooks / MCP / スラッシュコマンドが一括で消える。

### 1-10. 設定（settings.json）による指示

- 現役：`github.copilot.chat.reviewSelection.instructions`（コードレビュー）、`...commitMessageGeneration.instructions`（コミットメッセージ）、`...pullRequestDescriptionGeneration.instructions`（PR 説明）。`text` か `file` を持つオブジェクト配列。
- 非推奨（VS Code 1.102 以降）：codeGeneration / testGeneration の設定ベース指示 → ファイルベースへ移行。

### 1-11. 指示の優先順位（VS Code）

1. 個人（ユーザーレベル）— 最優先
2. リポジトリ（`.github/copilot-instructions.md` / `AGENTS.md`）
3. 組織レベル — 最低

複数の instructions ファイルが同時にマッチした場合、順序は保証されず全部結合される。矛盾する指示を書かないことが前提。コードレビュー用途の instructions は、レビュー対象ブランチではなく**ベースブランチ側**から読まれる。

---

## 2. Claude Code 側の定義ファイル

### 2-1. `CLAUDE.md` 階層（常時ロード）

| スコープ | パス | 用途 |
|---|---|---|
| 管理ポリシー | macOS `/Library/Application Support/ClaudeCode/CLAUDE.md`、Linux/WSL `/etc/claude-code/CLAUDE.md`、Windows `C:\Program Files\ClaudeCode\CLAUDE.md` | 全社規約。個人設定で除外不可 |
| ユーザー | `~/.claude/CLAUDE.md` | 全プロジェクト共通の個人設定 |
| プロジェクト | `./CLAUDE.md` または `./.claude/CLAUDE.md` | チーム共有（コミット） |
| ローカル | `./CLAUDE.local.md` | 個人用、`.gitignore` 対象 |

ロード規則：

- カレントディレクトリと**その上位すべて**の `CLAUDE.md` / `CLAUDE.local.md` を起動時にロード。上書きではなく**連結**。
- 順序はファイルシステムルート → 作業ディレクトリ（＝近いものが後に読まれる）。同一階層内では `CLAUDE.md` の後に `CLAUDE.local.md`。
- **サブディレクトリの `CLAUDE.md` は起動時にはロードされず、そのディレクトリのファイルを Claude が読んだ時点で遅延ロードされる。**
- 目安 200 行以内。4 MiB 超のファイルはスキップ。ブロックレベルの HTML コメントは注入前に除去される（人間向けメモをトークン消費なしで書ける）。
- `@path/to/file` インポート（相対/絶対、最大 4 ホップ）。バッククォートで囲めばリテラル扱い。インポートも起動時に展開されるのでコンテキスト削減にはならない。
- プロジェクト側メモリから作業ディレクトリ外を参照する「外部インポート」は初回に承認ダイアログが出る。
- `managed-settings.json` の `claudeMd` キーで、ファイルを配らず設定値として管理 CLAUDE.md を配布できる。
- モノレポで他チームの CLAUDE.md を除外：`claudeMdExcludes`（絶対パスのグロブ配列、レイヤー間でマージ）。
- `--add-dir` のディレクトリの CLAUDE.md は既定で読まれない。`CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` で有効化。

### 2-2. AGENTS.md との関係

Claude Code は `AGENTS.md` を読まない。共存させる定石は 2 つ。

```markdown
<!-- CLAUDE.md -->
@AGENTS.md

## Claude Code 固有
- src/billing/ 配下の変更はプランモードで
```

```bash
ln -s AGENTS.md CLAUDE.md   # Claude 固有の追記が不要な場合
```

Windows のシンボリックリンクは管理者権限か開発者モードが必要なので `@AGENTS.md` インポートが無難。`/init` は Cursor ルール（`.cursor/rules/`、`.cursorrules`）と Copilot ルール（`.github/copilot-instructions.md`）を読み取って CLAUDE.md に取り込む。`CLAUDE_CODE_NEW_INIT=1` を設定すると `AGENTS.md`、`.devin/rules/`、`.windsurf/rules/`、`.clinerules` も対象。`/import` コマンドで他エージェントの設定（指示ファイル・MCP・コマンド・サブエージェント・スキル）を一括取り込みできる（v2.1.213 以降）。

### 2-3. `.claude/rules/*.md`（トピック分割・パススコープ）

- `paths` frontmatter なし → 起動時ロード、優先度は `.claude/CLAUDE.md` と同じ。
- `paths` あり → **マッチするファイルを Claude が読んだ時に**ロード。全ツール使用時ではない。
- 再帰探索されるのでサブディレクトリ整理可（`.claude/rules/backend/api.md`）。
- シンボリックリンク可（共有ルール群を複数リポジトリにリンク、循環も安全に処理）。
- ユーザーレベル `~/.claude/rules/` はプロジェクトルールより**先に**ロード（＝プロジェクト側が優先）。
- ブレース展開は 1 ルールあたり 1,000 パターン / 4 MiB の予算。超えると未展開のまま扱われ何にもマッチしない。
- `[` はブラケット式として解釈されるため、リテラルで使うなら `\[` とエスケープ。

```markdown
---
paths:
  - "src/main/java/**/*.java"
  - "src/test/java/**/*Test.java"
---
# Java 実装ルール
- 例外は独自 ApplicationException に包む
- DAO 層に業務ロジックを書かない
```

### 2-4. `.claude/skills/<name>/SKILL.md`

配置と優先順位：

| レベル | パス | 適用範囲 |
|---|---|---|
| エンタープライズ | 管理設定ディレクトリ配下 `.claude/skills/` | 組織全員 |
| 個人 | `~/.claude/skills/<name>/SKILL.md` | 全プロジェクト |
| プロジェクト | `.claude/skills/<name>/SKILL.md` | そのプロジェクト |
| プラグイン | `<plugin>/skills/<name>/SKILL.md` | 有効化した場所 |

- 名前衝突時：エンタープライズ > 個人 > プロジェクト。プラグインは `plugin-name:skill-name` で名前空間分離。同名なら skill が `.claude/commands/` より優先。
- **カスタムコマンドは skills に統合済み**。`.claude/commands/deploy.md` と `.claude/skills/deploy/SKILL.md` はどちらも `/deploy`。既存 commands は動くが新規は skill 推奨。
- frontmatter（主要）：`name` / `description` / `when_to_use` / `argument-hint` / `arguments` / `disable-model-invocation`（ユーザー専用にする）/ `user-invocable: false`（Claude 専用にする）/ `allowed-tools` / `disallowed-tools` / `model` / `effort` / `context: fork` / `agent` / `background` / `hooks` / `paths` / `shell` / `metadata` / `license` / `compatibility`。
- **Agent Skills 標準として外部（claude.ai アップロード、Skills API、`package_skill.py`）で使えるのは `name` / `description` / `license` / `compatibility` / `metadata` / `allowed-tools` の 6 つのみ**。それ以外を含めるとパッケージング時にハードエラー。移植性を重視するならこの 6 つに絞る。
- 本文で使える置換：`$ARGUMENTS` / `$ARGUMENTS[N]` / `$N` / `$名前`、`${CLAUDE_SKILL_DIR}` / `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_SESSION_ID}` / `${CLAUDE_EFFORT}` / `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}`。
- 動的コンテキスト注入：`` !`git diff HEAD` ``（行頭または空白直後のみ有効）、複数行は ```` ```! ```` ブロック。失敗すると invocation 全体が中断するので、非ゼロ終了が想定される場合は `|| true`。`disableSkillShellExecution: true` で無効化可（managed settings 向け）。
- SKILL.md は 500 行以内、詳細は同ディレクトリの参照ファイルへ。一度ロードされた内容はターン跨ぎでコンテキストに残る（＝継続的なトークンコスト）。
- スキル一覧（名前＋description）は常にコンテキストに載る。数が増えると description が予算内（既定でコンテキスト窓の 1%）に収まるよう切り詰められる。`skillListingBudgetFraction` / `skillOverrides`（`on` / `name-only` / `user-invocable-only` / `off`）で調整。
- 評価：`skill-creator` プラグインで evals・A/B・description チューニングを自動化できる。

### 2-5. `.claude/agents/*.md`（サブエージェント）

- 独立コンテキストで動く。frontmatter で `name` / `description`（委譲判断に使われる）/ `tools`（読み取り専用に絞る等）/ `memory`（`project` / `local` / `user`）。
- 永続メモリ：`memory: project` → `.claude/agent-memory/<agent>/MEMORY.md`（コミット対象）、`local` → `.claude/agent-memory-local/`、`user` → `~/.claude/agent-memory/`。
- メインセッションの auto memory はサブエージェントには渡らない（fork を除く）。

### 2-6. 設定ファイルとその他

| ファイル | スコープ | 内容 |
|---|---|---|
| `.claude/settings.json` | プロジェクト（コミット） | `permissions` / `hooks` / `env` / `model` / `statusLine` / `outputStyle` など |
| `.claude/settings.local.json` | プロジェクト（gitignore） | 個人上書き |
| `~/.claude/settings.json` | ユーザー | 既定値 |
| `managed-settings.json` | システム | 企業強制。ほぼ最優先 |
| `.mcp.json` | プロジェクトルート | チーム共有 MCP サーバ（`${ENV_VAR}` 参照可） |
| `~/.claude.json` | ユーザー | アプリ状態・個人 MCP・信頼済みプロジェクト |
| `output-styles/*.md` | 両方 | システムプロンプトの差し替えセクション |
| `workflows/*.js` | 両方 | `/workflows` から保存する動的ワークフロー、`/<name>` になる |
| `.worktreeinclude` | プロジェクトルート | worktree 作成時にコピーする gitignore 済みファイル |
| `keybindings.json` / `themes/*.json` | ユーザー | キーバインド・テーマ |
| `~/.claude/projects/<project>/memory/` | ユーザー（自動生成） | auto memory。`MEMORY.md` 先頭 200 行 or 25KB を毎セッションロード |

設定の優先順位：管理設定 > CLI フラグ（`--permission-mode`、`--settings`）> `settings.local.json` > `settings.json`（プロジェクト）> `~/.claude/settings.json`。配列（`permissions.allow` 等）は全スコープでマージ、スカラー（`model` 等）は最も具体的な値。

---

## 3. サブフォルダに置いたらどうなるか

### 3-1. Copilot

| ケース | 挙動 |
|---|---|
| `.github/instructions/**` を階層化 | 再帰探索されるので**発見はされる**。ただし適用条件は `applyTo` のみ。フォルダ構造は整理目的であり、スコープ限定にはならない |
| サブフォルダに `AGENTS.md` | `chat.useNestedAgentsMdFiles`（実験的）が必要。中身ではなく「相対パス」をコンテキストに載せ、エージェントが編集対象に応じて選ぶ |
| モノレポでサブパッケージだけ開く | 既定では**親リポジトリの設定は読まれない**。`chat.useCustomizationsInParentRepositories` を有効にすると `.git` を見つけるまで上へ辿り、その間の全フォルダの customization（AGENTS.md・CLAUDE.md・instructions・prompts・agents・skills・hooks すべて）を収集。親フォルダの信頼（trust）が必要 |
| cloud agent / code review | hooks はデフォルトブランチ必須。レビュー時の instructions はベースブランチ側から読まれる |

結論：Copilot でフォルダ単位に効かせたいなら、**フォルダ階層に頼らず `applyTo: 'packages/frontend/**'` のようにグロブで書く**のが確実。

### 3-2. Claude Code

| ケース | 挙動 |
|---|---|
| 上位ディレクトリの `CLAUDE.md` | 起動時に全部ロード（ルート→カレントの順で連結） |
| サブディレクトリの `CLAUDE.md` | 起動時ではなく、そのディレクトリのファイルを読んだ時に遅延ロード |
| `.claude/rules/` の `paths` 付き | マッチファイルを読んだ時にロード。`/compact` 後は再マッチするまで戻らない |
| ネストした `.claude/skills/` | 起動時には読まれない。そのサブディレクトリのファイルを読み書きした時点で有効化。同名衝突時はディレクトリ修飾名（`apps/web:deploy`）になり、無修飾で呼ぶとルート側がロードされ「該当ディレクトリの変種も呼べ」という指示が付随する |
| プロジェクトスキルの上位探索 | 起動ディレクトリからリポジトリルートまでの `.claude/skills/` は起動時にロードされる |
| `--add-dir` で足したディレクトリ | `.claude/skills/` と `.claude/commands/` は例外的にロードされる。CLAUDE.md は環境変数が必要。output-styles 等は読まれない |
| 除外したい | `claudeMdExcludes` に絶対パスのグロブ |

`/compact` 後に指示が消えたように見える典型原因は、①会話中だけの指示、②未再ロードのネスト CLAUDE.md、③まだマッチしていない `paths` 付きルール。プロジェクトルートの CLAUDE.md は compaction 後にディスクから再注入される。

---

## 4. 用途別の使い分け（判断フロー）

```
その規則は毎回必要か？
├─ Yes → 全ファイルに適用？
│        ├─ Yes → copilot-instructions.md / AGENTS.md / CLAUDE.md
│        └─ No  → *.instructions.md (applyTo) / .claude/rules (paths)
└─ No  → 手順（複数ステップ・スクリプト・テンプレートを伴う）か？
         ├─ Yes → SKILL.md
         │        ├─ 実行タイミングを人が握りたい（deploy/commit） → disable-model-invocation: true
         │        └─ 背景知識として自動適用したい → user-invocable: false
         └─ No  → 役割・ツール制限を変えたい？
                  ├─ Yes → *.agent.md / .claude/agents/*.md
                  └─ No  → 必ず実行させたい？ → hooks / permissions
```

- 「フォーマッタを実行して」を instructions に書くのは誤り。それは hooks の仕事。
- CLAUDE.md が 200 行に近づいたら rules へ分割、手順に育ったら skill へ移す。
- prompt ファイル（Copilot）は Agent Host 非対応なので、新規は skill に寄せる。

---

## 5. スコープ階層（誰に効くか）

| 層 | Copilot | Claude Code |
|---|---|---|
| 企業/管理ポリシー | 組織レベル instructions・custom agents（`github.copilot.chat.organizationInstructions.enabled` 等） | 管理 CLAUDE.md、`managed-settings.json`、エンタープライズ skills |
| ユーザー（全プロジェクト） | `~/.copilot/instructions`、`~/.copilot/agents`、`~/.copilot/skills`、`~/.copilot/hooks`、VS Code プロファイル（Settings Sync 対象） | `~/.claude/CLAUDE.md`、`~/.claude/rules/`、`~/.claude/skills/`、`~/.claude/agents/`、`~/.claude/settings.json` |
| プロジェクト（コミット） | `.github/**`、`.claude/**` | `CLAUDE.md`、`.claude/**`、`.mcp.json` |
| プロジェクト（個人・非コミット） | ワークスペース設定 | `CLAUDE.local.md`、`.claude/settings.local.json` |

- Copilot のユーザー指示は Settings Sync の「Prompts and Instructions」で端末間同期できる。ただし Agent Host セッションはプロファイルではなく `~/.copilot/*` を読むため、移行機能（`chat.customizations.userDataMigration.enabled`）で移す必要がある。移行後のファイルは Settings Sync 対象外。
- Claude Code は worktree を跨ぐ個人設定を `CLAUDE.local.md` に書くと worktree ごとに消えるので、`@~/.claude/my-project-instructions.md` のインポートにする。

---

## 6. 両ツール併用の推奨構成

```
repo/
├── AGENTS.md                        # 共通の常時ロード指示（単一ソース）
├── CLAUDE.md                        # @AGENTS.md + Claude 固有の追記
├── .github/
│   ├── copilot-instructions.md      # AGENTS.md へのリンク＋Copilot 固有
│   ├── instructions/*.instructions.md
│   ├── prompts/*.prompt.md          # 既存資産のみ。新規は skills へ
│   ├── agents/*.agent.md
│   └── hooks/*.json
└── .claude/
    ├── skills/<name>/SKILL.md       # ★両ツールが読む共通資産
    ├── rules/*.md                   # paths スコープ（Copilot も .claude/rules を読む）
    ├── agents/*.md                  # Copilot も .claude/agents を読む
    └── settings.json
```

重複を作らない要点：

1. 常時ロードの本文は `AGENTS.md` 1 本。CLAUDE.md はインポート、copilot-instructions.md は Markdown リンクで参照。
2. スキルは `.claude/skills/` に集約すれば Copilot（VS Code / CLI / cloud agent）と Claude Code の両方から読める。
3. サブエージェントは `.claude/agents/` に置けば VS Code が Claude 形式として解釈する。
4. 条件付きルールは `.claude/rules/`（`paths`）に寄せると両対応。ただし Copilot 独自の `applyTo` は使えないので記法を揃える。

---

## 7. 導入プラン

### フェーズ 0：現状把握（0.5 日）

- 既存の `copilot-instructions.md` / `CLAUDE.md` / `.cursorrules` 等を棚卸し。
- Copilot：チャット応答の References、右クリック → Diagnostics、Agent Debug Logs で「実際に何がロードされているか」を確認。
- Claude Code：`/context`（Memory files セクション）、`/memory`、`/doctor`、`/hooks`、`/mcp`。`--debug` で parse エラーも見る。

### フェーズ 1：常時ロード指示の一本化（1 日）

- `AGENTS.md` を作成（Copilot は `/init`、Claude Code は `/init` で下書き生成 → 手で削る）。
- `CLAUDE.md` に `@AGENTS.md` を書く（Windows はシンボリックリンクではなくインポート）。
- 200 行以内。「コードから読み取れること（ディレクトリ構成・依存一覧）」は削り、「落とし穴・理由・ツール既定と異なる規約」を残す。`/doctor` の trim 提案が使える。
- 検証：Copilot で References に出るか、Claude Code で `/context` に出るか。

### フェーズ 2：条件付きルールの分離（1〜2 日）

- 常時ロードから、特定の層にしか関係しない内容を切り出す。
  - Copilot：`.github/instructions/*.instructions.md` に `applyTo`
  - Claude Code：`.claude/rules/*.md` に `paths`
  - 両対応にするなら `.claude/rules/` へ寄せる
- Java 系プロジェクトなら例：`src/main/java/**`（実装規約）、`**/*Test.java`（テスト規約）、`src/main/webapp/**`（画面・JSP 規約）、`db/migration/**`（DDL 規約）。
- 検証：対象ファイルを開いた時だけコンテキストに載ることを Diagnostics / `/context` で確認。

### フェーズ 3：手順のスキル化（2〜3 日、継続）

- 「毎回同じ指示を貼っている」ものを 1 つずつ `.claude/skills/<name>/SKILL.md` に移す。
- 標準 6 フィールド（`name` / `description` / `license` / `compatibility` / `metadata` / `allowed-tools`）だけで書けば claude.ai・Skills API にも持ち出せる。Claude Code 固有機能を使う場合は移植不可になる点を承知の上で。
- description は「いつ使うか」を具体的なトリガーフレーズで書く。ここがマッチ精度の 8 割。
- 副作用のあるもの（deploy、リリース、外部送信）は `disable-model-invocation: true`。
- 検証：`skill-creator` プラグインで evals（有効時 / 無効時の比較、A/B、description チューニング）。Copilot 側は Chat Customizations Evaluations 拡張（`/analyze-prompt`、Waza）。

### フェーズ 4：役割と決定的制御（2 日）

- レビュー用エージェント（読み取り専用ツールのみ）を `.claude/agents/code-reviewer.md` に定義 → Copilot / Claude Code 双方で使える。
- 「必ず走らせたい」ものを hooks に移す。
  - Copilot：`.github/hooks/*.json`（cloud agent で使うならデフォルトブランチへマージ）
  - Claude Code：`settings.json` の `hooks`（`PostToolUse` matcher `Edit|Write` でフォーマッタ）
- 禁止事項は Claude Code なら `permissions.deny`、Copilot なら `PreToolUse` フックで。
- 注意：VS Code 側の hooks は matcher を無視して全イベントで走るので、スクリプト側で対象を判定する。

### フェーズ 5：配布と運用（継続）

- 複数リポジトリに配るなら Copilot は Agent Plugins、Claude Code は plugin + marketplace。共有ルールはシンボリックリンク（`ln -s ~/company-rules .claude/rules/company`）も可。
- 組織レベル instructions / custom agents を使うなら該当設定を有効化して周知。
- 四半期ごとに棚卸し：矛盾する指示の削除、使われていないスキルの `skillOverrides: "off"`、CLAUDE.md の再 trim。

### 進め方の原則

- 一度に全部作らない。フェーズ 1 だけで効果測定 → 効いた実感が出てから 2 へ。
- 変更は 1 種類ずつ。指示・スキル・フックを同時に足すと、どれが効いたか分からなくなる。
- 「モデルが従わない」時は、まず**ロードされているか**を確認（診断ビュー / `/context`）。ロードされていて従わないなら、具体性不足か矛盾か、そもそも hooks 案件。

---

## 8. 落とし穴チェックリスト

- [ ] `copilot-instructions.md` を `.github/` 以外に置いていないか（他パスは無効）
- [ ] `.instructions.md` に `applyTo` を書き忘れていないか（未指定＝自動適用されない）
- [ ] `.claude/rules` 側で `applyTo` を書いていないか（正しくは `paths`）
- [ ] 常時ロードのファイルが 200 行を超えていないか（遵守率が落ちる）
- [ ] 相互に矛盾する指示が複数ファイルに残っていないか（順序保証なし、任意に片方が選ばれる）
- [ ] フォーマット・Lint をルールで指示していないか（hooks / formatter の仕事）
- [ ] cloud agent 用 hooks をデフォルトブランチにマージしたか
- [ ] リポジトリから取得した skill の `allowed-tools` をレビューしたか（ワークスペース信頼をバイパスして権限を自己付与できる）
- [ ] hooks スクリプトの stdin JSON をサニタイズしているか（インジェクション対策）
- [ ] モノレポでサブフォルダだけ開く運用なら `chat.useCustomizationsInParentRepositories` を有効にしたか
- [ ] Claude Code のユーザー設定を Agent Host 用に `~/.copilot/*` へ移行したか（Copilot 側の話）
- [ ] 標準外 frontmatter を含む skill を claude.ai へ持ち出そうとしていないか（ハードエラー）

---

## 9. 出典

- VS Code / Agent customization concepts — https://code.visualstudio.com/docs/agents/concepts/customization
- VS Code / Create and manage agent customizations（モノレポ・親リポジトリ探索）— https://code.visualstudio.com/docs/agent-customization/overview
- VS Code / Custom instructions — https://code.visualstudio.com/docs/agent-customization/custom-instructions
- VS Code / Prompt files — https://code.visualstudio.com/docs/agent-customization/prompt-files
- VS Code / Custom agents — https://code.visualstudio.com/docs/agent-customization/custom-agents
- VS Code / Agent Skills — https://code.visualstudio.com/docs/agent-customization/agent-skills
- VS Code / Hooks — https://code.visualstudio.com/docs/agent-customization/hooks
- VS Code / Agent plugins — https://code.visualstudio.com/docs/agent-customization/agent-plugins
- GitHub Docs / About agent skills — https://docs.github.com/en/copilot/concepts/agents/about-agent-skills
- GitHub Docs / Adding agent skills — https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
- GitHub Docs / Customize agent workflows with hooks — https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/use-hooks
- Claude Code / Memory — https://code.claude.com/docs/en/memory
- Claude Code / Skills — https://code.claude.com/docs/en/skills
- Claude Code / .claude directory — https://code.claude.com/docs/en/claude-directory
- Claude Code / Subagents — https://code.claude.com/docs/en/sub-agents
- Claude Code / Settings — https://code.claude.com/docs/en/settings
- Agent Skills 標準 — https://agentskills.io
- コミュニティ資産 — https://github.com/github/awesome-copilot / https://github.com/anthropics/skills
