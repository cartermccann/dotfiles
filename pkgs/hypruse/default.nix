{
  lib,
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
  grim,
  wtype,
  systemd,
  imagemagick,
  wl-clipboard,
}:

python3Packages.buildPythonApplication {
  pname = "hypruse";
  version = "0.10.0";
  pyproject = true;

  # Release 0.10.0 plus its version/lock metadata follow-ups; includes Lua IPC.
  src = fetchFromGitHub {
    owner = "IlyasKhallouki";
    repo = "hypruse";
    rev = "7dd11acae0a5631825907f0ba8340dd4088998c4";
    hash = "sha256-e9ByUZK4rXA+1MlE/9+mynzSKFY5t7necIMjlZgOT/I=";
  };

  build-system = [ python3Packages.hatchling ];
  dependencies = [ python3Packages.mcp ];
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];
  pythonImportsCheck = [ "hypruse" ];
  # Upstream pyproject excludes live-desktop e2e tests by default.

  # Use the session's hyprctl, matching the running compositor, from PATH.
  # Do not pull a different Hyprland release into this standalone package.
  postFixup = ''
    wrapProgram "$out/bin/hypruse" \
      --prefix PATH ${
        lib.makeBinPath [
          grim
          wtype
          systemd
          imagemagick
          wl-clipboard
        ]
      }
  '';

  meta = {
    description = "Separate MCP server for Hyprland desktop observation and control";
    homepage = "https://github.com/IlyasKhallouki/hypruse";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hypruse";
  };
}
