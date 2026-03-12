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

      # Source matugen-generated theme if available, otherwise use fallback Nord
      if-shell "test -f ~/.config/tmux/matugen-theme.conf" \
        "source-file ~/.config/tmux/matugen-theme.conf" \
        "set -g status-style 'bg=#2E3440,fg=#D8DEE9'; \
         set -g pane-border-style 'fg=#3B4252'; \
         set -g pane-active-border-style 'fg=#88C0D0'; \
         set -g window-status-current-style 'bg=#434C5E,fg=#88C0D0,bold'; \
         set -g window-status-style 'fg=#D8DEE9'; \
         set -g message-style 'bg=#2E3440,fg=#D8DEE9'; \
         set -g mode-style 'bg=#434C5E,fg=#D8DEE9'; \
         set -g status-left '#[bg=#5E81AC,fg=#2E3440,bold] #S #[default] '; \
         set -g status-right '#[fg=#D8DEE9] %H:%M  %a %b %d '"
    '';
  };
}
