{ config, pkgs, user, ... }:

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

    # Ollama (runs in docker container as root)
    ollama = "sudo docker exec -it ollama ollama";
    ai = "sudo docker exec -it ollama ollama run qwen3.5:9b";

    # OpenClaw
    claw = "openclaw";
  };
in
{
  programs.fish = {
    enable = true;
    inherit shellAliases;
    interactiveShellInit = ''
      set -g fish_greeting
      set -gx NH_FLAKE $HOME/dotfiles
      fish_add_path $HOME/.local/bin

      # Autosuggestion color — visible but subtle on dark backgrounds
      set -U fish_color_autosuggestion 90909a

      # Load matugen-generated fzf colors
      if test -f $HOME/.config/fzf/colors
        set -gx FZF_DEFAULT_OPTS (cat $HOME/.config/fzf/colors | string collect)
      end

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
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:$PATH"
      # Load matugen-generated fzf colors
      [ -f "$HOME/.config/fzf/colors" ] && export FZF_DEFAULT_OPTS="$(cat "$HOME/.config/fzf/colors")"
    '';
  };

  # Starship prompt — static config with palette color references.
  # Palette values are overwritten by matugen via wallpaper-set (see theme.nix).
  programs.starship = {
    enable = true;
    settings = let
      # Use JSON unicode escapes to reliably get PUA glyphs into Nix strings
      sep = builtins.fromJSON ''"\uE0B4"'';   # round right powerline
      nix = builtins.fromJSON ''"\uF313"'';   # nix logo
    in {
      palette = "matugen";
      format = builtins.concatStringsSep "" [
        "[░▒▓](color_primary)"
        "[${nix} ](bg:color_primary fg:#090c0c)"
        "[${sep}](bg:color_secondary fg:color_primary)"
        "$directory"
        "[${sep}](fg:color_secondary bg:color_surface_container)"
        "$git_branch"
        "$git_status"
        "[${sep}](fg:color_surface_container bg:color_surface)"
        "$nodejs"
        "$rust"
        "$golang"
        "$php"
        "[${sep}](fg:color_surface)"
        "$character"
      ];

      character = {
        success_symbol = "[${sep}](fg:color_primary) ";
        error_symbol = "[${sep}](fg:color_error) ";
      };

      directory = {
        format = "[ $path ]($style)";
        style = "fg:#e3e5e5 bg:color_secondary";
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
        style = "bg:color_surface_container";
        format = "[[ $symbol $branch ](fg:color_primary bg:color_surface_container)]($style)";
      };

      git_status = {
        style = "bg:color_surface_container";
        format = "[[($all_status$ahead_behind )](fg:color_primary bg:color_surface_container)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:color_surface";
        format = "[[ $symbol ($version) ](fg:color_primary bg:color_surface)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:color_surface";
        format = "[[ $symbol ($version) ](fg:color_primary bg:color_surface)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:color_surface";
        format = "[[ $symbol ($version) ](fg:color_primary bg:color_surface)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:color_surface";
        format = "[[ $symbol ($version) ](fg:color_primary bg:color_surface)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_surface";
        format = "[[  $time ](fg:color_on_surface_variant bg:color_surface)]($style)";
      };

      aws.disabled = true;

      # Fallback palette (used before first wallpaper-set)
      palettes.matugen = {
        color_primary = "#81A1C1";
        color_secondary = "#88C0D0";
        color_tertiary = "#8FBCBB";
        color_surface = "#2E3440";
        color_surface_container = "#3B4252";
        color_on_surface = "#D8DEE9";
        color_on_surface_variant = "#a0a9cb";
        color_error = "#BF616A";
      };
    };
  };

  # fzf integration — colors loaded from matugen-generated file at runtime
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
