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
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-numbers = true;
    };
  };

  programs.bat.enable = true;
}
