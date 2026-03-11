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
    rebuild = "sudo nixos-rebuild switch --flake ~/dotfiles#$(hostname | tr 'A-Z' 'a-z')";
    nrs = "sudo nixos-rebuild switch --flake ~/dotfiles#$(hostname | tr 'A-Z' 'a-z')";
    update = "sudo nixos-rebuild switch --flake ~/dotfiles#$(hostname | tr 'A-Z' 'a-z') --upgrade";

    # Modern replacements
    ls = "eza --icons";
    ll = "eza -la --icons";
    cat = "bat";
    grep = "rg";

    # Ollama (runs in podman container as root)
    ollama = "sudo podman exec -it ollama ollama";
    ai = "sudo podman exec -it ollama ollama run qwen3.5:9b";

    # OpenClaw
    claw = "openclaw";
  };
in
{
  programs.fish = {
    enable = true;
    inherit shellAliases;
    interactiveShellInit = ''
      fish_add_path $HOME/.local/bin $HOME/.cargo/bin

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
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      format = builtins.concatStringsSep "" [
        "[░▒▓](#a3aed2)"
        "[  ](bg:#a3aed2 fg:#090c0c)"
        "[](bg:#769ff0 fg:#a3aed2)"
        "$directory"
        "[](fg:#769ff0 bg:#394260)"
        "$git_branch"
        "$git_status"
        "[](fg:#394260 bg:#212736)"
        "$nodejs"
        "$rust"
        "$golang"
        "$php"
        "[](fg:#212736 bg:#1d2230)"
        "$time"
        "[ ](fg:#1d2230)"
        "\n$character"
      ];
      directory = {
        format = "[ $path ]($style)";
        style = "fg:#e3e5e5 bg:#769ff0";
        truncation_length = 3;
        truncation_symbol = "…/";
      };
      directory.substitutions = {
        "Documents" = "󰈙 ";
        "Downloads" = " ";
        "Music" = " ";
        "Pictures" = " ";
      };
      git_branch = {
        symbol = "";
        style = "bg:#394260";
        format = "[[ $symbol $branch ](fg:#769ff0 bg:#394260)]($style)";
      };
      git_status = {
        style = "bg:#394260";
        format = "[[($all_status$ahead_behind )](fg:#769ff0 bg:#394260)]($style)";
      };
      nodejs = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };
      rust = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };
      golang = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };
      php = {
        symbol = "";
        style = "bg:#212736";
        format = "[[ $symbol ($version) ](fg:#769ff0 bg:#212736)]($style)";
      };
      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:#1d2230";
        format = "[[  $time ](fg:#a0a9cb bg:#1d2230)]($style)";
      };
    };
  };

  # fzf integration
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    defaultOptions = [
      "--color=bg+:#3B4252,bg:#2E3440,spinner:#81A1C1,hl:#81A1C1"
      "--color=fg:#D8DEE9,header:#81A1C1,info:#EBCB8B,pointer:#81A1C1"
      "--color=marker:#81A1C1,fg+:#D8DEE9,prompt:#81A1C1,hl+:#81A1C1"
    ];
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
