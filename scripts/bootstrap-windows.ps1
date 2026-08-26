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
  @{ Id = "tree-sitter.tree-sitter-cli"; Label = "tree-sitter" },
  @{ Id = "AutoHotkey.AutoHotkey"; Label = "autohotkey-v2" }
)

$workPackages = @(
  @{ Id = "Microsoft.AzureCLI"; Label = "azure-cli" },
  @{ Id = "Microsoft.DotNet.SDK.8"; Label = "dotnet-sdk" },
  @{ Id = "Astral-sh.uv"; Label = "uv" }
)

$bunGlobalPackages = @(
  "opencode-ai"
)

$cargoGlobalPackages = @(
  "codemark-cli"
)

function Test-IsInteractive {
  try {
    return ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected)
  } catch {
    return $false
  }
}

function Sync-BunGlobalPackages {
  if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Warning "bun is not available on PATH; skipping bun global package sync."
    return
  }

  $bunGlobalPackageJson = Join-Path $HOME ".bun/install/global/package.json"

  foreach ($pkg in $bunGlobalPackages) {
    $isInstalled = $false
    if (Test-Path $bunGlobalPackageJson) {
      try {
        $json = Get-Content -Raw -Path $bunGlobalPackageJson | ConvertFrom-Json
        if ($null -ne $json.dependencies -and $null -ne $json.dependencies.$pkg) {
          $isInstalled = $true
        }
      } catch {
        Write-Warning "Failed reading $bunGlobalPackageJson: $($_.Exception.Message)"
      }
    }

    if (-not $isInstalled) {
      Write-Host "==> bun: installing $pkg"
      bun install -g $pkg | Out-Host
    }
  }

  if (-not (Test-Path $bunGlobalPackageJson)) {
    return
  }

  $installed = @()
  try {
    $json = Get-Content -Raw -Path $bunGlobalPackageJson | ConvertFrom-Json
    if ($null -ne $json.dependencies) {
      $installed = $json.dependencies.PSObject.Properties.Name
    }
  } catch {
    Write-Warning "Failed reading $bunGlobalPackageJson for drift check: $($_.Exception.Message)"
    return
  }

  $interactive = Test-IsInteractive
  foreach ($pkg in $installed) {
    if ($bunGlobalPackages -contains $pkg) {
      continue
    }

    if ($interactive) {
      $ans = Read-Host "  bun: '$pkg' isn't declared in bunGlobalPackages. Remove it? [y/N]"
      if ($ans -match '^[Yy]$') {
        bun remove -g $pkg | Out-Host
      }
    } else {
      Write-Host "  bun: '$pkg' is installed but not in bunGlobalPackages (not removing, non-interactive)"
    }
  }
}

function Install-CargoGlobalPackage {
  param(
    [Parameter(Mandatory = $true)][string]$Package
  )

  switch ($Package) {
    "codemark-cli" {
      cargo install --git https://github.com/DanielCardonaRojas/codemark codemark-cli | Out-Host
      break
    }
    default {
      throw "No install mapping configured for cargo package '$Package'."
    }
  }
}

function Sync-CargoGlobalPackages {
  if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Warning "cargo is not available on PATH; skipping cargo global package sync. Open a new shell and re-run bootstrap after mise rust installs."
    return
  }

  $cargoListOutput = cargo install --list 2>$null
  $installed = @()
  foreach ($line in $cargoListOutput) {
    if ($line -match '^([^\s]+)\sv[^\s]+:$') {
      $installed += $Matches[1]
    }
  }

  foreach ($pkg in $cargoGlobalPackages) {
    if ($installed -contains $pkg) {
      continue
    }
    Write-Host "==> cargo: installing $pkg"
    Install-CargoGlobalPackage -Package $pkg
  }

  $interactive = Test-IsInteractive
  foreach ($pkg in $installed) {
    if ($cargoGlobalPackages -contains $pkg) {
      continue
    }

    if ($interactive) {
      $ans = Read-Host "  cargo: '$pkg' isn't declared in cargoGlobalPackages. Remove it? [y/N]"
      if ($ans -match '^[Yy]$') {
        cargo uninstall $pkg | Out-Host
      }
    } else {
      Write-Host "  cargo: '$pkg' is installed but not in cargoGlobalPackages (not removing, non-interactive)"
    }
  }
}

function Enable-CapsRemap {
  # Wire the CapsLock dual-role script (chezmoi-applied caps.ahk) to run at
  # login via a Startup-folder shortcut. Idempotent: recreates the shortcut
  # on every bootstrap so the target path stays correct after moves.
  $script = Join-Path $HOME ".local\scripts\caps.ahk"
  if (-not (Test-Path $script)) {
    Write-Warning "caps.ahk not found at $script (did chezmoi apply run?); skipping caps remap setup."
    return
  }

  $ahkExe = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey32.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  if (-not $ahkExe) {
    Write-Warning "AutoHotkey v2 not found; skipping caps remap setup. Re-run bootstrap after AutoHotkey installs."
    return
  }

  $startup = [Environment]::GetFolderPath("Startup")
  $lnkPath = Join-Path $startup "caps-dual-role.lnk"
  $wsh = New-Object -ComObject WScript.Shell
  $lnk = $wsh.CreateShortcut($lnkPath)
  $lnk.TargetPath = $ahkExe
  $lnk.Arguments = "`"$script`""
  $lnk.Save()
  Write-Host "==> caps remap: startup shortcut written to $lnkPath"
}

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

Enable-CapsRemap

if (Get-Command mise -ErrorAction SilentlyContinue) {
  Write-Host "==> Installing runtimes from mise config"
  mise install | Out-Host
}

Sync-BunGlobalPackages
Sync-CargoGlobalPackages

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
