#!/usr/bin/env pwsh
# Windows bootstrap for this dotfiles repo.
# Installs core tooling with winget, applies Windows dotfiles via chezmoi,
# and installs runtimes declared in ~/.config/mise/config.toml.

[CmdletBinding()]
param(
  [ValidateSet("personal", "work")]
  [string]$Profile = "personal"
)

$ErrorActionPreference = "Stop"

if (-not $IsWindows) {
  throw "This script is for Windows only."
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$chezmoiSource = Join-Path $repoRoot "windows/chezmoi"

if (-not (Test-Path $chezmoiSource)) {
  throw "Expected chezmoi source at $chezmoiSource"
}

function Install-WingetPackage {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [string]$Label = $Id
  )

  Write-Host "==> Installing $Label ($Id)"
  winget install `
    --id $Id `
    --exact `
    --accept-source-agreements `
    --accept-package-agreements `
    --disable-interactivity | Out-Host
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget is required but not available on PATH."
}

$basePackages = @(
  @{ Id = "twpayne.chezmoi"; Label = "chezmoi" },
  @{ Id = "jdx.mise"; Label = "mise" },
  @{ Id = "Git.Git"; Label = "git" },
  @{ Id = "GitHub.cli"; Label = "gh" },
  @{ Id = "Neovim.Neovim"; Label = "neovim" },
  @{ Id = "Starship.Starship"; Label = "starship" },
  @{ Id = "BurntSushi.ripgrep.MSVC"; Label = "ripgrep" },
  @{ Id = "sharkdp.fd"; Label = "fd" },
  @{ Id = "sharkdp.bat"; Label = "bat" },
  @{ Id = "eza-community.eza"; Label = "eza" },
  @{ Id = "ajeetdsouza.zoxide"; Label = "zoxide" },
  @{ Id = "junegunn.fzf"; Label = "fzf" },
  @{ Id = "jqlang.jq"; Label = "jq" },
  @{ Id = "JesseDuffield.lazygit"; Label = "lazygit" },
  @{ Id = "JesseDuffield.lazydocker"; Label = "lazydocker" },
  @{ Id = "tree-sitter.tree-sitter-cli"; Label = "tree-sitter" }
)

$workPackages = @(
  @{ Id = "Microsoft.AzureCLI"; Label = "azure-cli" },
  @{ Id = "Microsoft.DotNet.SDK.8"; Label = "dotnet-sdk" },
  @{ Id = "Astral-sh.uv"; Label = "uv" }
)

$failedPackages = New-Object System.Collections.Generic.List[string]

foreach ($pkg in $basePackages) {
  try {
    Install-WingetPackage -Id $pkg.Id -Label $pkg.Label
  } catch {
    $failedPackages.Add($pkg.Id) | Out-Null
    Write-Warning "Failed to install $($pkg.Id): $($_.Exception.Message)"
  }
}

if ($Profile -eq "work") {
  foreach ($pkg in $workPackages) {
    try {
      Install-WingetPackage -Id $pkg.Id -Label $pkg.Label
    } catch {
      $failedPackages.Add($pkg.Id) | Out-Null
      Write-Warning "Failed to install $($pkg.Id): $($_.Exception.Message)"
    }
  }
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
  throw "chezmoi is not available after installation."
}

Write-Host "==> Applying Windows dotfiles with chezmoi ($Profile profile)"
chezmoi init --apply --source $chezmoiSource

if (Get-Command mise -ErrorAction SilentlyContinue) {
  Write-Host "==> Installing runtimes from mise config"
  mise install | Out-Host
}

if (-not (Get-Command codemark -ErrorAction SilentlyContinue)) {
  Write-Host "==> Installing codemark"
  Invoke-RestMethod "https://github.com/DanielCardonaRojas/codemark/releases/latest/download/codemark-cli-installer.ps1" | Invoke-Expression
}

Write-Host ""
Write-Host "Windows profile '$Profile' was applied from:"
Write-Host "  $chezmoiSource"
Write-Host ""

$linuxOnly = @(
  "ghostty module (Linux-first in this repo; no guaranteed native parity here)",
  "tmux workflow + kanata service wiring (WSL/Linux implementation)",
  "aerc and tut (no reliable native Windows package path in this setup)",
  "pi-coding-agent Nix package (Nix-only)",
  "azure-artifacts-credprovider env wiring from Linux work profile"
)

Write-Host "Linux-only or not-parity items:"
foreach ($item in $linuxOnly) {
  Write-Host "  - $item"
}

if ($failedPackages.Count -gt 0) {
  Write-Warning ""
  Write-Warning "Some packages did not install via winget:"
  $failedPackages | Sort-Object -Unique | ForEach-Object { Write-Warning "  - $_" }
  Write-Warning "You can still proceed; install these manually if needed."
}
