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
    historyLimit = 50000;

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

      # csi-u extended keys: Shift/Ctrl-modified keys reach TUI agents
      # (Claude Code under ghostty needs this for e.g. shift+enter)
      set -g extended-keys on
      set -s extended-keys-format csi-u
      set -g allow-passthrough on
      set -g focus-events on
      set -g renumber-windows on
      set -g detach-on-destroy off    # killing a session falls into the next one

      # Window auto-rename from cwd basename
      set -g automatic-rename on
      set -g automatic-rename-format '#{b:pane_current_path}'

      # Prefix-free nav (Alt layer; existing C-a prefix binds untouched)
      bind -n M-Enter   split-window -v -c "#{pane_current_path}"
      bind -n M-S-Enter split-window -h -c "#{pane_current_path}"
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9
      bind -n M-Left  previous-window
      bind -n M-Right next-window
      bind -n M-Up   switch-client -p
      bind -n M-Down switch-client -n

      # Mode indicators on status-right (COPY / prefix / ZOOM). Colors use
      # terminal palette names, so they ride the ghostty palette for free.
      set -g status-right '#{?pane_in_mode,#[fg=yellow]COPY ,}#{?client_prefix,#[fg=blue]⌘ ,}#{?window_zoomed_flag,#[fg=magenta]ZOOM ,}'
    '';
  };
}
