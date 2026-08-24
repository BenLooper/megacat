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
