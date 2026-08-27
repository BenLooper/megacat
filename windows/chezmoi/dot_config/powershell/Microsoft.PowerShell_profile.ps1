$ErrorActionPreference = "Stop"

if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (&starship init powershell)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

function ls { eza --icons @Args }
function ll { eza -l --icons --git @Args }
function la { eza -la --icons --git @Args }
function lt { eza --tree --icons --level=2 @Args }

function cat { bat @Args }

Set-Alias g git

function gs {
  git status @Args
}

function gd {
  git diff @Args
}

function gl {
  git log --oneline --graph --decorate
}

function lg {
  lazygit
}

function dots {
  chezmoi apply --source "$HOME/dotfiles/windows/chezmoi"
}

if (Get-Command opencode -ErrorAction SilentlyContinue) {
  Set-Alias oc opencode
}

if (Get-Command codemark -ErrorAction SilentlyContinue) {
  Set-Alias cm codemark
}

# tmux prefix+m analog: run a long command, get notified (taskbar
# flash + toast) when it finishes. Works for scriptblocks and commands:
#   watch { cargo build }     watch npm install
function watch {
  if ($args.Count -eq 1 -and $args[0] -is [scriptblock]) {
    & $args[0]
  } elseif ($args.Count -gt 0) {
    & @args
  }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
    "$env:USERPROFILE\.local\scripts\agent-notify.ps1" shell done
}
