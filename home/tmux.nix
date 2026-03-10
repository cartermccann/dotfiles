{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    terminal = "tmux-256color";
    escapeTime = 0;
    historyLimit = 10000;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      nord
    ];

    extraConfig = ''
      # Split panes with | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # New window in current path
      bind c new-window -c "#{pane_current_path}"

      # Vim pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Vim pane resize
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Copy mode with wl-copy (Wayland clipboard)
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"

      # Status bar at top
      set -g status-position top

      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"
    '';
  };
}
