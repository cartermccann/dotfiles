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
      sep = builtins.fromJSON ''"\uE0B4"'';
      nix = builtins.fromJSON ''"\uF313"'';
      c = config.lib.stylix.colors.withHashtag;
    in {
      palette = "stylix";
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
        style = "fg:${c.base05} bg:color_secondary";
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

      palettes.stylix = {
        color_primary = c.base0D;
        color_secondary = c.base0C;
        color_tertiary = c.base0B;
        color_surface = c.base01;
        color_surface_container = c.base02;
        color_on_surface = c.base05;
        color_on_surface_variant = c.base04;
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
