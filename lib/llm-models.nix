# Single source of truth for local Ollama model tags.
#
# Consumed by modules/ollama.nix (tiered preload) and home/shell.nix (chat
# aliases) so an alias can never point at a model the preloader doesn't pull.
# When these change, keep the alias table in ~/.claude/rules/nix-environment.md
# in sync.
#
# High tier budgets ~10 GB of the 12 GB VRAM, leaving ~2 GB for the
# compositor/ghostty. Prefer QAT tags over post-hoc Q4 quants when they exist.
# Preload only ever adds — retire old models manually via `ollama rm`.
let
  # `daily` is the solid general-purpose model for this box: a 12B at QAT int4
  # leaves comfortable headroom on the 12 GB card, so it doubles as the
  # reasoning/tool-calling model. There is deliberately no separate "test
  # model" slot — the previous one (Qwythos-9B, 6.8 GB) was preloaded for
  # months and never once invoked.
  daily = "gemma4:12b-it-qat"; # daily chat default: 7.2 GB, fits 12 GB better than q8
  quick = "qwen3.5:4b"; # quick jobs (dictation cleanup, summaries): 3.4 GB
  fim = "qwen2.5-coder:3b-base"; # FIM tab-completion (minuet): 1.9 GB, stays resident
  small = "llama3.2:3b"; # CPU-friendly fallback for low/medium tiers
  embed = "nomic-embed-text:latest"; # vault-cognee-bridge embeddings: 274 MB, 768 dims, CPU-fine
in
{
  inherit
    daily
    quick
    fim
    small
    embed
    ;

  tiers = {
    high = [
      daily
      fim
      quick
      embed
    ];
    medium = [
      quick
      small
      embed
    ];
    low = [
      small
      embed
    ];
  };
}
