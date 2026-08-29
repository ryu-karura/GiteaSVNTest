# 20260829_06 Claude / Copilot 定義ファイル

方針: 完全に別々（.claude/ と .github/ を独立記述）。共通の手順本体は ai-instructions/ を両者が参照。

## Claude 側（.claude/）

- `rules/ai-execution.md` … frontmatter `paths: ["**"]`。必須ルール + 参照先 + メモリ運用。
- `skills/gitea-pr/SKILL.md`
- `skills/redmine-ticket/SKILL.md`
- `skills/pr-and-ticket/SKILL.md`
- `CLAUDE.md` に「GiteaSVNTest プロジェクト」節を追記（RTK 節の後ろ）。

## Copilot 側（.github/）

- `copilot-instructions.md` … 常時ロード。絶対規則 + 参照先（相対リンク）+ メモリ運用。
- `instructions/ai-execution.instructions.md` … frontmatter `applyTo: '**'`。要点版。
- `skills/gitea-pr/SKILL.md`
- `skills/redmine-ticket/SKILL.md`
- `skills/pr-and-ticket/SKILL.md`

両者の SKILL は文面を個別に書き起こし（コピーではない）。内容の実体は ai-instructions/ 側。

## 全作業完了

作業1〜7 完了。残: README にリポジトリ構成節を追記（任意）、実コンテナ起動での検証（未実施）。
