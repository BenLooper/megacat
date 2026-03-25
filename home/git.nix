# home/git.nix
# ============================================================
# Git configuration.
#
# This is equivalent to editing ~/.gitconfig manually, but managed
# by Nix — so it's always in sync across machines and version-controlled.
#
# TODO: Fill in your real name and email below before applying.
# ============================================================
{ ... }: {

  programs.git = {
    enable = true;

    settings = {
      # These appear in every commit you make. Use your real name and
      # the email associated with your GitHub/GitLab account.
      user.name  = "BenLooper";
      user.email = "TODO@example.com";  # TODO: replace with your actual email

      # ============================================================
      # ALIASES
      # Short commands. `git st` = `git status`, etc.
      # ============================================================
      alias = {
        st   = "status";
        co   = "checkout";
        br   = "branch";
        ci   = "commit";

        # One-line graph log — great for seeing branch history at a glance
        lg   = "log --oneline --graph --decorate --all";

        # Undo the last commit but keep your changes staged (safe — no data lost)
        undo = "reset --soft HEAD~1";

        # Show which files changed in the last commit
        changed = "diff-tree --no-commit-id -r --name-only HEAD";
      };

      # When you `git pull`, rebase your local commits on top of the remote
      # instead of creating a merge commit. Keeps history linear and clean.
      pull.rebase = true;

      # New repos created with `git init` use "main" instead of "master".
      init.defaultBranch = "main";

      # Histogram diff is slower but produces better, more readable diffs
      # (fewer spurious changes shown when you move code around).
      diff.algorithm = "histogram";

      # Show untracked files individually, not collapsed as a directory name.
      status.showUntrackedFiles = "all";
    };

    # ============================================================
    # GLOBAL GITIGNORE
    # These patterns are ignored in EVERY repo on this machine.
    # Use this for editor/OS noise that shouldn't be tracked anywhere.
    # Project-specific ignores still go in each repo's .gitignore.
    # ============================================================
    ignores = [
      # macOS metadata
      ".DS_Store"
      # Editor temp/swap files
      "*~"
      "*.swp"
      ".idea/"
      ".vscode/"
      # Nix build outputs (the `result` symlink nix build creates)
      "result"
      "result-*"
    ];
  };
}
