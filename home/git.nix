{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "cartermccann";
        email = "cjmccann00@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      credential."https://github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
      # Include theme-applied delta config (overrides syntax-theme at runtime)
      include.path = "~/.config/delta/theme";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "Nord"; # default fallback; overridden by theme-apply via include
      line-numbers = true;
    };
  };

  # Bat with custom syntax themes (used by delta)
  programs.bat = {
    enable = true;
    themes = {
      catppuccin-mocha = {
        src = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "bat";
          rev = "main";
          hash = "sha256-lJapSgRVENTrbmpVyn+UQabC9fpV1G1e+CdlJ090uvg=";
        };
        file = "themes/Catppuccin Mocha.tmTheme";
      };
      tokyonight_night = {
        src = pkgs.fetchFromGitHub {
          owner = "folke";
          repo = "tokyonight.nvim";
          rev = "main";
          hash = "sha256-4zfkv3egdWJ/GCWUehV0MAIXxsrGT82Wd1Qqj1SCGOk=";
        };
        file = "extras/sublime/tokyonight_night.tmTheme";
      };
      kanagawa = {
        src = pkgs.fetchFromGitHub {
          owner = "rebelot";
          repo = "kanagawa.nvim";
          rev = "master";
          hash = "sha256-nHcQWTX4x4ala6+fvh4EWRVcZMNk5jZiZAwWhw03ExE=";
        };
        file = "extras/tmTheme/kanagawa.tmTheme";
      };
      rose-pine = {
        src = pkgs.fetchFromGitHub {
          owner = "rose-pine";
          repo = "tm-theme";
          rev = "main";
          hash = "sha256-GUFdv5V5OZ2PG+gfsbiohMT23LWsrZda34ReHBr2Xy0=";
        };
        file = "dist/rose-pine.tmTheme";
      };
      # Nord and gruvbox-dark are built-in to bat/delta
    };
  };
}
