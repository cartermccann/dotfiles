{
  config,
  lib,
  pkgs,
  user,
  ...
}:

# whisperlivekit — local Deepgram-compatible STT server, so anarlog can
# transcribe meetings without sending audio to a cloud vendor.
#
# Why this shape, after two dead ends:
#   * anarlog gates its own on-device STT to macOS/aarch64 and silently
#     rewrites the config to cloud STT anywhere else.
#   * Its "Custom" STT provider is Deepgram-only ("We only support Deepgram
#     compatible endpoints"), and the client connects to {base}/listen over a
#     WebSocket — see their own test, api_base = "ws://127.0.0.1:52693/v1".
#     So an OpenAI-shaped server cannot serve this slot at all — which is why
#     the Parakeet server that used to live in pkgs/ was dropped.
#   * OWhisper, the server that slot was designed for, is retired: source gone
#     from the monorepo, binaries 404, Homebrew formula points at a dead URL.
#
# WhisperLiveKit serves exactly `WS /v1/listen` speaking Deepgram Live
# Transcription, which matches what anarlog builds. Verified end to end on
# kronos: raw s16le PCM in, correct transcript out.
#
# The package itself is a uv tool, not a nix derivation, because torch +
# CUDA wheels in nixpkgs are a quagmire. Install
# (or upgrade) it with:
#
#   uv tool install --force "whisperlivekit[cu129]" \
#     --with nvidia-cublas-cu12 --with nvidia-cudnn-cu12 --python 3.13
#
# Three NixOS-specific facts are load-bearing in the env below:
#   * torch needs libstdc++ on LD_LIBRARY_PATH.
#   * CUDA_VISIBLE_DEVICES="" forces CPU. GPU *works* (torch sees the 5070 at
#     sm_120 once /run/opengl-driver/lib is on the path), but nvidia's
#     cuda-pathfinder shells out to /sbin/ldconfig during model warmup, and
#     NixOS has no /sbin at all, so startup aborts. CPU sidesteps it.
#   * --pcm-input bypasses ffmpeg. Without it the server pipes audio through
#     `ffmpeg -i pipe:0` with no input format, which cannot sniff headerless
#     PCM — and raw PCM is exactly what anarlog sends. Symptom is
#     "Cannot write, FFmpeg state: STOPPED" and an empty transcript.
let
  homeAbs = "/home/${user}";
  wlk = "${homeAbs}/.local/bin/wlk";
  credentialsFile = "${homeAbs}/.config/credentials/whisperlivekit.env";
  port = 8000;
  model = "small";

  runtimeLibs = [ pkgs.stdenv.cc.cc.lib ];
in
{
  systemd.user.services.whisperlivekit = {
    Unit = {
      Description = "WhisperLiveKit — local Deepgram-compatible STT server for anarlog";
      Documentation = [ "https://github.com/QuentinFuxa/WhisperLiveKit" ];
      After = [ "network.target" ];
      # uv tool install is imperative; don't restart-loop if it's missing.
      ConditionPathExists = [
        wlk
        credentialsFile
      ];
    };

    Service = {
      Type = "simple";
      EnvironmentFile = credentialsFile;
      Environment = [
        "LD_LIBRARY_PATH=${lib.makeLibraryPath runtimeLibs}"
        "CUDA_VISIBLE_DEVICES="
        "PATH=${
          lib.makeBinPath [
            pkgs.ffmpeg
            pkgs.coreutils
          ]
        }"
      ];
      # --host 127.0.0.1 keeps this off the tailnet, which matters here because
      # modules/networking.nix trusts tailscale0. The token is belt-and-braces
      # (and the anarlog Custom form requires an API key field anyway).
      ExecStart = lib.concatStringsSep " " [
        wlk
        "--host 127.0.0.1"
        "--port ${toString port}"
        "--model ${model}"
        "--language en"
        "--pcm-input"
        "--api-token \${WLK_API_TOKEN}"
      ];
      Restart = "on-failure";
      RestartSec = 10;
      # Model load is slow on first run (downloads from HF).
      TimeoutStartSec = "10min";
      Nice = 5;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
