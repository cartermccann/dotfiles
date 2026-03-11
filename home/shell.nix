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
        "[](fg:#3B4252)"
        "$directory"
        "[](bg:#434C5E fg:#3B4252)"
        "$git_branch"
        "$git_status"
        "[](fg:#434C5E)"
        " $python$nodejs$elixir$rust$nix_shell$docker_context"
        "$character"
      ];
      directory = {
        format = "[ $path ]($style)";
        style = "bg:#3B4252 fg:#81A1C1 bold";
        truncation_length = 3;
      };
      git_branch = {
        format = "[  $branch ]($style)";
        style = "bg:#434C5E fg:#A3BE8C bold";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style)";
        style = "bg:#434C5E fg:#BF616A bold";
      };
      python = {
        format = "[](fg:#EBCB8B)[ $symbol$version ](bg:#EBCB8B fg:#2E3440)[](fg:#EBCB8B) ";
        symbol = " ";
      };
      nodejs = {
        format = "[](fg:#A3BE8C)[ $symbol$version ](bg:#A3BE8C fg:#2E3440)[](fg:#A3BE8C) ";
        symbol = " ";
      };
      elixir = {
        format = "[](fg:#B48EAD)[ $symbol$version ](bg:#B48EAD fg:#2E3440)[](fg:#B48EAD) ";
        symbol = " ";
      };
      rust = {
        format = "[](fg:#D08770)[ $symbol$version ](bg:#D08770 fg:#2E3440)[](fg:#D08770) ";
        symbol = " ";
      };
      nix_shell = {
        format = "[](fg:#88C0D0)[  $state ](bg:#88C0D0 fg:#2E3440)[](fg:#88C0D0) ";
      };
      docker_context = {
        format = "[](fg:#81A1C1)[ $symbol$context ](bg:#81A1C1 fg:#2E3440)[](fg:#81A1C1) ";
        symbol = " ";
      };
      character = {
        success_symbol = " [❯](bold #A3BE8C)";
        error_symbol = " [❯](bold #BF616A)";
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
