{
  config,
  lib,
  pkgs,
  user,
  ...
}:

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

    # Ollama (runs in the rootful podman container)
    ollama = "sudo podman exec -it ollama ollama";
    ai = "sudo podman exec -it ollama ollama run gemma4:12b-it-qat";
    qwen = "sudo podman exec -it ollama ollama run qwen3.5:4b";
    coder = "sudo podman exec -it ollama ollama run qwen2.5-coder:3b-base";
    qwy = "sudo podman exec -it ollama ollama run hf.co/empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF:Q4_K_M";
  };

  comcreateBanner = pkgs.writeShellScriptBin "comcreate-banner" (
    builtins.readFile ../scripts/comcreate-banner.sh
  );

  # Animated cascade-reveal wrapper for the neon fastfetch config.
  ff = pkgs.writeShellScriptBin "ff" (builtins.readFile ../scripts/ff-cascade.sh);
in
{
  home.packages = [
    comcreateBanner
    ff
  ];

  # Neon-gradient fastfetch config (declarative; `ff` animates its reveal).
  xdg.configFile."fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;

  programs.fish = {
    enable = true;
    inherit shellAliases;
    interactiveShellInit = ''
      function fish_greeting
        if not set -q TMUX
          ff
        end
      end
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

      # One canonical tmux session
      function t
        tmux attach; or tmux new -s work
      end

      # Heavy mode: the GPU fits one of ollama or llama-server (Qwen3.6-35B MoE),
      # so these swap between them. First run downloads ~24 GB;
      # watch with: sudo podman logs -f llama-heavy
      function heavy --description "swap ollama out, big MoE model in"
        sudo systemctl stop podman-ollama
        sudo systemctl start podman-llama-heavy
        echo "heavy mode up: http://127.0.0.1:8089 (web UI + OpenAI-compatible API)"
        echo "back to normal: heavy-stop"
      end

      function heavy-stop --description "swap llama-heavy out, ollama back in"
        sudo systemctl stop podman-llama-heavy
        sudo systemctl start podman-ollama
        echo "heavy mode down, ollama restored"
      end

      # Git worktrees as `repo--branch` sibling dirs.
      # (named gwa/gwr — ga/gd are taken by git add / git diff aliases)
      function gwa --description "git worktree add -b <branch> ../<repo>--<branch>"
        if test (count $argv) -ne 1
          echo "usage: gwa <branch>"; return 1
        end
        set -l repo (basename (git rev-parse --show-toplevel)); or return 1
        set -l dir ../$repo--$argv[1]
        git worktree add -b $argv[1] $dir; and cd $dir
      end

      function gwr --description "remove current worktree dir + its branch"
        set -l dir (basename $PWD)
        set -l branch (string split --max 1 -- '--' $dir)[2]
        if test -z "$branch"
          echo "gwr: '$dir' is not a repo--branch worktree dir"; return 1
        end
        gum confirm "Remove worktree $dir and delete branch $branch?"; or return 1
        cd ..
        git -C (string replace -- "--$branch" "" $dir) worktree remove $dir --force
        and git -C (string replace -- "--$branch" "" $dir) branch -D $branch
      end
    '';
  };

  programs.bash = {
    enable = true;
    inherit shellAliases;
    initExtra = ''
      export PATH="$HOME/.local/bin:$PATH"
      if [[ $- == *i* && -z "$TMUX" ]]; then comcreate-banner; fi
    '';
  };

  stylix.targets.starship.enable = false;
  stylix.targets.neovim.enable = false;
  stylix.targets.niri.enable = false;

  programs.starship = {
    enable = true;
    settings =
      let
        # Tokyo Night theme (starship.rs preset palette): ░▒▓ periwinkle fade-in,
        # pointed separators, segments stepping into navy, rounded cap, blue accent
        # text. https://starship.rs/presets/tokyo-night
        # Powerline glyphs via fromJSON so the ASCII escapes survive editing.
        arrow = builtins.fromJSON ''"\uE0B0"'';
        capR = builtins.fromJSON ''"\uE0B4"'';
        dither = "░▒▓";
      in
      {
        palette = "cc";
        add_newline = true;
        format = builtins.concatStringsSep "" [
          "[${dither}](fg:cc1)"
          "$os"
          "$username"
          "[${arrow}](fg:cc1 bg:cc2)"
          "$directory"
          "[${arrow}](fg:cc2 bg:cc3)"
          "$git_branch"
          "$git_status"
          "[${arrow}](fg:cc3 bg:cc4)"
          "$nodejs"
          "$rust"
          "$golang"
          "$python"
          "$php"
          "$java"
          "[${arrow}](fg:cc4 bg:cc5)"
          "$docker_context"
          "[${arrow}](fg:cc5 bg:cc6)"
          "$time"
          "[${capR}](fg:cc6)"
          "$fill"
          "$cmd_duration"
          "$line_break"
          "$character"
        ];

        fill.symbol = " ";

        os = {
          disabled = false;
          format = "[ $symbol]($style)";
          style = "bg:cc1 fg:cc_ink";
        };

        os.symbols = {
          NixOS = " ";
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
          style_user = "bg:cc1 fg:cc_ink";
          style_root = "bg:cc1 fg:cc_ink";
          format = "[ $user ]($style)";
        };

        directory = {
          format = "[ $path ]($style)";
          style = "fg:cc_fg bg:cc2";
          truncation_length = 3;
          truncation_symbol = "…/";
          substitutions = {
            "Documents" = "󰈙 ";
            "Downloads" = " ";
            "Music" = "󰝚 ";
            "Pictures" = " ";
          };
        };

        git_branch = {
          symbol = "";
          style = "bg:cc3";
          format = "[[ $symbol $branch ](fg:cc2 bg:cc3)]($style)";
        };

        git_status = {
          style = "bg:cc3";
          format = "[[($all_status$ahead_behind )](fg:cc2 bg:cc3)]($style)";
        };

        nodejs = {
          symbol = "";
          style = "bg:cc4";
          format = "[[ $symbol( $version) ](fg:cc2 bg:cc4)]($style)";
        };
        rust = {
          symbol = "";
          style = "bg:cc4";
          format = "[[ $symbol( $version) ](fg:cc2 bg:cc4)]($style)";
        };
        golang = {
          symbol = "";
          style = "bg:cc4";
          format = "[[ $symbol( $version) ](fg:cc2 bg:cc4)]($style)";
        };
        python = {
          symbol = "";
          style = "bg:cc4";
          format = "[[ $symbol( $version) ](fg:cc2 bg:cc4)]($style)";
        };
        php = {
          symbol = "";
          style = "bg:cc4";
          format = "[[ $symbol( $version) ](fg:cc2 bg:cc4)]($style)";
        };
        java = {
          symbol = "";
          style = "bg:cc4";
          format = "[[ $symbol( $version) ](fg:cc2 bg:cc4)]($style)";
        };

        docker_context = {
          symbol = "";
          style = "bg:cc5";
          format = "[[ $symbol( $context) ](fg:cc2 bg:cc5)]($style)";
        };

        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:cc6";
          format = "[[  $time ](fg:cc_dim bg:cc6)]($style)";
        };

        cmd_duration = {
          min_time = 500;
          format = "[ 󰔟 $duration ](fg:cc_dim)";
        };

        character = {
          success_symbol = "[❯](bold fg:cc_green)";
          error_symbol = "[❯](bold fg:cc_red)";
          vimcmd_symbol = "[❮](bold fg:cc1)";
        };

        aws.disabled = true;

        palettes.cc = {
          cc1 = "#a3aed2"; # periwinkle head
          cc2 = "#769ff0"; # blue (directory bg + accent text)
          cc3 = "#394260"; # git
          cc4 = "#212736"; # languages (navy)
          cc5 = "#212736"; # docker (navy)
          cc6 = "#1d2230"; # time (darkest navy)
          cc_ink = "#090c0c"; # text on periwinkle head
          cc_fg = "#e3e5e5"; # text on directory
          cc_dim = "#a0a9cb"; # text on time
          cc_green = "#9ece6a"; # success prompt char
          cc_red = "#f7768e"; # error prompt char
        };
      };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  # atuin (rich shell history)
  programs.atuin = {
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
