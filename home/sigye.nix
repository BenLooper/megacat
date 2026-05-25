# home/sigye.nix
# ============================================================
# sigye (시계) — a beautiful terminal clock with ASCII art fonts.
#
# Built from source since it's not yet in nixpkgs.
# Auto-launches in screensaver mode on every terminal open.
# Press `q` to dismiss.
# ============================================================
{ config, pkgs, sigye-pkg, ... }: {

  home.packages = [ sigye-pkg ];

  xdg.configFile."sigye/config.toml".text = ''
    font_name = "Terrace"
    color_theme = "GradientFrost"
    time_format = "TwelveHour"
    animation_style = "None"
    animation_speed = "Slow"
    colon_blink = false
    show_seconds = false
    background_style = "GradientWave"
  '';
}
