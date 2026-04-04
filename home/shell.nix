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
      c = config.lib.stylix.colors.withHashtag;
    in {
      palette = "stylix";
      format = builtins.concatStringsSep "" [
        # Segment 1: OS + user (mauve)
        "[](color_mauve)"
        "$os"
        "$username"
        "[${sep}](bg:color_red fg:color_mauve)"
        # Segment 2: Directory (red/peach)
        "$directory"
        "[${sep}](fg:color_red bg:color_peach)"
        # Segment 3: Git (peach/yellow)
        "$git_branch"
        "$git_status"
        "[${sep}](fg:color_peach bg:color_green)"
        # Segment 4: Languages (green)
        "$nodejs"
        "$rust"
        "$golang"
        "$python"
        "$php"
        "$java"
        "[${sep}](fg:color_green bg:color_blue)"
        # Segment 5: Docker/env (blue)
        "$docker_context"
        "[${sep}](fg:color_blue bg:color_surface)"
        # Segment 6: Time (surface)
        "$time"
        "[${sep}](fg:color_surface)"
        "$character"
      ];

      os = {
        disabled = false;
        style = "bg:color_mauve fg:color_base";
      };

      os.symbols = {
        NixOS = " ";
        Linux = "󰌽 ";
        Arch = "󰣇 ";
        Ubuntu = "󰕈 ";
        Fedora = "󰣛 ";
        Debian = "󰣚 ";
        Macos = "󰀵 ";
        Windows = "󰍲 ";
      };

      username = {
        show_always = true;
        style_user = "bg:color_mauve fg:color_base";
        style_root = "bg:color_mauve fg:color_base";
        format = "[ $user ]($style)";
      };

      directory = {
        format = "[ $path ]($style)";
        style = "fg:color_base bg:color_red";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = "󰝚 ";
          "Pictures" = " ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:color_peach";
        format = "[[ $symbol $branch ](fg:color_base bg:color_peach)]($style)";
      };

      git_status = {
        style = "bg:color_peach";
        format = "[[($all_status$ahead_behind )](fg:color_base bg:color_peach)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol( $version) ](fg:color_base bg:color_green)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol( $version) ](fg:color_base bg:color_green)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol( $version) ](fg:color_base bg:color_green)]($style)";
      };

      python = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol( $version) ](fg:color_base bg:color_green)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol( $version) ](fg:color_base bg:color_green)]($style)";
      };

      java = {
        symbol = "";
        style = "bg:color_green";
        format = "[[ $symbol( $version) ](fg:color_base bg:color_green)]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:color_blue";
        format = "[[ $symbol( $context) ](fg:color_teal bg:color_blue)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_surface";
        format = "[[  $time ](fg:color_text bg:color_surface)]($style)";
      };

      character = {
        success_symbol = " ";
        error_symbol = "[](fg:color_red) ";
      };

      aws.disabled = true;

      palettes.stylix = {
        # Rainbow segments (warm → cool)
        color_mauve = c.base0E;    # segment 1: OS + user
        color_red = c.base08;      # segment 2: directory
        color_peach = c.base09;    # segment 3: git
        color_yellow = c.base0A;   # character vim visual
        color_green = c.base0B;    # segment 4: languages
        color_blue = c.base0D;     # segment 5: docker
        color_teal = c.base0C;     # docker fg accent
        # Backgrounds
        color_base = c.base00;     # dark fg on colored segments
        color_surface = c.base02;  # segment 6: time
        color_text = c.base05;     # light text on dark bg
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
