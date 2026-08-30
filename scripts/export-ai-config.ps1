<#
.SYNOPSIS
  配布用 AI 指示ファイルを対象プロジェクトへコピーする（export-ai-config.sh の PowerShell 版）。
  正リストは docs/ai/DISTRIBUTION.md。

.EXAMPLE
  ./scripts/export-ai-config.ps1 -Dest C:\path\to\target-project
  ./scripts/export-ai-config.ps1 -Dest ..\other-repo -DryRun
#>
param(
  [Parameter(Mandatory = $true)][string]$Dest,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$srcRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$destRoot = (Resolve-Path $Dest).Path

if ($srcRoot -eq $destRoot) { throw "source and target are the same" }
if (-not (Test-Path $destRoot -PathType Container)) { throw "not a directory: $Dest" }

# 配布物（DISTRIBUTION.md と一致させる）
$items = @(
  'CLAUDE.md',
  '.env.example',
  '.claude/rules',
  '.claude/skills',
  '.github/copilot-instructions.md',
  '.github/instructions',
  '.github/skills',
  'docs/ai'
)

Write-Host "src : $srcRoot"
Write-Host "dest: $destRoot"
if ($DryRun) { Write-Host "(dry-run)" }
Write-Host ""

foreach ($item in $items) {
  $src = Join-Path $srcRoot $item
  $dst = Join-Path $destRoot $item
  if (-not (Test-Path $src)) { Write-Host "SKIP (missing in source): $item"; continue }
  if ($DryRun) { Write-Host "COPY $item"; continue }

  $dstParent = Split-Path $dst -Parent
  if (-not (Test-Path $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }
  if (Test-Path $src -PathType Container) {
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $src $dst -Recurse
  } else {
    Copy-Item $src $dst -Force
  }
  Write-Host "COPY $item"
}

Write-Host ""
Write-Host "完了。コピー先で以下を調整する（docs/ai/DISTRIBUTION.md「導入手順」参照）:"
Write-Host "  - CLAUDE.md の「# GiteaSVNTest プロジェクト」節を対象プロジェクト向けに書き換え"
Write-Host "  - .env.example: コピー先に既存のものがあればマージ。cp .env.example .env して値を記入"
Write-Host "  - docs/ai/env-vars.md の URL / OWNER / REPO を対象環境の実値に"
Write-Host "  - 環境変数の投入（<repo>/.env または ~/.env、CI は Secrets）"
Write-Host "  - docs/ai/healthcheck.md で疎通確認"
