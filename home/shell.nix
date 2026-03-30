{ config, lib, pkgs, user, ... }:

let
  shellAliases = {
    # Navigation
    ".." = "cd ..";
    "..." = "cd ../..";

    # Git
    gs = "git status";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git log --oneline --graph";
    gd = "git diff";
    gb = "git branch";

    # Docker
    dc = "docker-compose";
    dps = "docker ps";
    dimg = "docker images";
    dlog = "docker logs";

    # Nix
    nrs = "nh os switch ~/dotfiles";
    update = "nh os switch ~/dotfiles --update";

    # Modern replacements
    ls = "eza --icons";
    ll = "eza -la --icons";
    cat = "bat";
    grep = "rg";
    y = "yazi";
    df = "duf";
    http = "xh";
    md = "glow";

    # Ollama (runs in docker container as root)
    ollama = "sudo docker exec -it ollama ollama";
    ai = "sudo docker exec -it ollama ollama run qwen3.5:9b";

  };
in
{
  programs.fish = {
    enable = true;
    inherit shellAliases;
    interactiveShellInit = ''
      set -g fish_greeting
      set -gx NH_FLAKE $HOME/dotfiles
      set -gx GOPATH $HOME/.local/share/go
      set -gx GOBIN $HOME/.local/bin
      fish_add_path $HOME/.local/bin

      # Autosuggestion color — visible but subtle on dark backgrounds
      set -U fish_color_autosuggestion 90909a

      # tmux dev layout
      function dev
        tmux new-session -d -s dev -c (pwd)
        tmux split-window -h -p 40
        tmux split-window -v -p 50
        tmux select-pane -t 1
        tmux send-keys -t dev:1.1 "nvim" Enter
        tmux select-pane -t dev:1.1
        tmux attach -t dev
      end
    '';
  };

  programs.bash = {
    enable = true;
    inherit shellAliases;
    initExtra = ''
      export PATH="$HOME/.local/bin:$PATH"
    '';
  };

  stylix.targets.starship.enable = false;
  stylix.targets.neovim.enable = false;
  stylix.targets.niri.enable = false;

  programs.starship = {
    enable = true;
    settings = let
      sep = builtins.fromJSON ''"\uE0B0"'';
      nix = builtins.fromJSON ''"\uF313"'';
      c = config.lib.stylix.colors.withHashtag;
    in {
      palette = "stylix";
      format = builtins.concatStringsSep "" [
        "[${nix} ](bg:color_accent fg:color_accent_fg)"
        "[${sep}](bg:color_dir fg:color_accent)"
        "$directory"
        "[${sep}](fg:color_dir bg:color_muted)"
        "$git_branch"
        "$git_status"
        "[${sep}](fg:color_muted bg:color_deep)"
        "$nodejs"
        "$rust"
        "$golang"
        "$php"
        "[${sep}](fg:color_deep)"
        "$character"
      ];

      character = {
        success_symbol = " ";
        error_symbol = "[](fg:color_error) ";
      };

      directory = {
        format = "[ $path ]($style)";
        style = "fg:color_dir_fg bg:color_dir";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:color_muted";
        format = "[[ $symbol $branch ](fg:color_muted_fg bg:color_muted)]($style)";
      };

      git_status = {
        style = "bg:color_muted";
        format = "[[($all_status$ahead_behind )](fg:color_muted_fg bg:color_muted)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:color_deep";
        format = "[[ $symbol ($version) ](fg:color_deep_fg bg:color_deep)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:color_deep";
        format = "[[ $symbol ($version) ](fg:color_deep_fg bg:color_deep)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:color_deep";
        format = "[[ $symbol ($version) ](fg:color_deep_fg bg:color_deep)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:color_deep";
        format = "[[ $symbol ($version) ](fg:color_deep_fg bg:color_deep)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_deep";
        format = "[[  $time ](fg:color_deep_fg bg:color_deep)]($style)";
      };

      aws.disabled = true;

      palettes.stylix = {
        # Segment 1: Nix icon — bold accent
        color_accent = c.base0D;
        color_accent_fg = c.base00;
        # Segment 2: Directory — secondary accent, still distinct from primary
        color_dir = c.base02;
        color_dir_fg = c.base0C;
        # Segment 3: Git — muted surface
        color_muted = c.base01;
        color_muted_fg = c.base0D;
        # Segment 4: Language — deepest, near terminal bg
        color_deep = c.base00;
        color_deep_fg = c.base04;
        # Utility
        color_error = c.base08;
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  # zoxide (smart cd)
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  # direnv for per-project nix shells
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
