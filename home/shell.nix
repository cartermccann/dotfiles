{ config, pkgs, ... }:

{
  programs.bash = {
    enable = true;
    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "~" = "cd ~";

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

      # Ollama
      ai = "ollama run llama3.2:3b";

      # OpenClaw
      claw = "openclaw";
    };
    initExtra = ''
      export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.cargo/bin:$PATH"

      # Set npm global prefix for NixOS (Nix store is read-only)
      if command -v npm &> /dev/null; then
        npm set prefix ~/.npm-global 2>/dev/null
      fi
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      format = "$directory$git_branch$git_status$python$nodejs$elixir$rust$nix_shell$docker_context$character";
      directory = {
        style = "bold #81A1C1";
        truncation_length = 3;
      };
      git_branch = {
        style = "bold #A3BE8C";
        symbol = " ";
      };
      git_status.style = "bold #BF616A";
      python.style = "#EBCB8B";
      nodejs.style = "#A3BE8C";
      elixir.style = "#B48EAD";
      rust.style = "#D08770";
      nix_shell = {
        style = "#88C0D0";
        symbol = " ";
      };
      docker_context.style = "#81A1C1";
      character = {
        success_symbol = "[❯](bold #A3BE8C)";
        error_symbol = "[❯](bold #BF616A)";
      };
    };
  };

  # fzf integration
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    defaultOptions = [
      "--color=bg+:#3B4252,bg:#2E3440,spinner:#81A1C1,hl:#81A1C1"
      "--color=fg:#D8DEE9,header:#81A1C1,info:#EBCB8B,pointer:#81A1C1"
      "--color=marker:#81A1C1,fg+:#D8DEE9,prompt:#81A1C1,hl+:#81A1C1"
    ];
  };

  # direnv for per-project nix shells
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
