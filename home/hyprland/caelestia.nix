{
  config,
  lib,
  pkgs,
  caelestia,
  ...
}:
# Caelestia: the Quickshell-based shell behind the "Hyprland (Caelestia)" login
# tile. It replaces waybar + swaync + fuzzel + swayosd wholesale for that
# session — bar, notifications, launcher, OSD and lock screen all come from it.
#
# Themed from lib/palette.nix, but not the way the waybar session is. Caelestia
# is Material 3 end to end: every surface, container and "on-" role comes out of
# one seed colour, so handing it a Base16 slot map would fight the system. What
# it gets instead is the Ouranos cobalt as that seed, expanded into a full M3
# role set by Caelestia's own generator (see the ouranosScheme derivation).
let
  system = pkgs.stdenv.hostPlatform.system;
  palette = import ../../lib/palette.nix;

  # ── The Ouranos scheme ────────────────────────────────────────────────────
  # Caelestia resolves a named scheme from
  # <cli-package>/data/schemes/<name>/<flavour>/<mode>.txt, which lives in the
  # store — so a house scheme is generated at build time and grafted into a
  # copy of the CLI. `caelestia scheme list` then shows it alongside the
  # bundled fourteen and the shell's own picker can select it.
  schemeName = "ouranos";
  schemeFlavour = "cobalt";

  # M3 variant, and the one real design knob here. It is baked in at build
  # time: for a file-backed scheme the CLI reads the .txt verbatim and never
  # re-runs the generator, so `caelestia scheme set --variant ...` cannot
  # change it. `content` was picked over the alternatives because it is the
  # only variant that keeps both halves of Ouranos:
  #
  #   variant     primary          background       vs. Ouranos
  #   tonalspot   #bcc5ee (C26)    #0d0e12 (C5)     accent too washed out
  #   vibrant     #94aaff (C48)    #08082f (C28)    ground is navy, not black
  #   content     #b6c4ff (C35)    #11131b (C9)     both land
  #
  # (Ouranos night: accent #3b6bff C73, ground #0a0c11 C6.) Material re-tones
  # the seed for contrast — nothing survives at tone 50 on a dark ground — so
  # `primary` is a lighter cobalt than base0D. The hue carries through exactly
  # at 274.8°, which is what makes it read as the house colour.
  schemeVariant = "content";

  baseCli = caelestia.inputs.caelestia-cli.packages.${system}.default;
  cliDeps = baseCli.propagatedBuildInputs or [ ];
  cliPython =
    lib.findFirst (p: (p.pname or "") == "python3")
      (throw "caelestia-cli no longer propagates python3; the scheme generator needs its interpreter")
      cliDeps;

  # Run the generator against the pinned CLI's own modules rather than a
  # nixpkgs python env: it calls caelestia.utils.material.generator, and
  # nixpkgs' materialyoucolor (2.0.10) is old enough to take gen_scheme's
  # legacy branch and blow up on a missing primary_paletteKeyColor. Importing
  # the caelestia package runs its argparse tree, which reaches PIL, so every
  # propagated input goes on the path — the non-python ones are simply
  # directories that do not exist.
  sitePackages = p: "${p}/lib/python${cliPython.pythonVersion}/site-packages";

  ouranosScheme =
    pkgs.runCommand "caelestia-scheme-${schemeName}"
      {
        nativeBuildInputs = [ cliPython ];
        PYTHONPATH = lib.concatMapStringsSep ":" sitePackages ([ baseCli ] ++ cliDeps);
      }
      ''
        python3 ${../../scripts/caelestia-ouranos-scheme.py} \
          "${palette.night.raw.base0D}" "${schemeName}" "${schemeFlavour}" "${schemeVariant}" "$out"
      '';

  ouranosCli = baseCli.overrideAttrs (old: {
    # Newline-joined, not concatenated: upstream's postInstall ends mid-line
    # (installShellCompletion ...) and would otherwise swallow the first
    # command here as an extra argument.
    postInstall =
      (old.postInstall or "")
      + "\n"
      + ''
        schemeDir="$out/lib/python${cliPython.pythonVersion}/site-packages/caelestia/data/schemes/${schemeName}/${schemeFlavour}"
        install -Dm444 ${ouranosScheme}/dark.txt "$schemeDir/dark.txt"
        install -Dm444 ${ouranosScheme}/light.txt "$schemeDir/light.txt"
      '';
  });

  # withCli passes the CLI through as a runtime dep of the shell, so the shell
  # has to be rebuilt against the grafted copy too — otherwise the scheme is
  # visible to the `caelestia` on PATH but not to the one the shell shells out
  # to for its own picker.
  ouranosShell = caelestia.packages.${system}.with-cli.override { caelestia-cli = ouranosCli; };

  # Seed values for ~/.config/caelestia/shell.json. NOT fed to
  # `programs.caelestia.settings` — see the activation script below for why.
  shellSeed = {
    background = {
      # swww owns the wallpaper on this machine across all three sessions,
      # and ~/wallpaper.png is a cross-session contract (niri autostart,
      # hyprlock background, both wallpaper pickers). Leaving Caelestia's own
      # wallpaper layer on would put a second wallpaper *above* swww's on the
      # Background layer. false keeps the surface — the desktop clock and
      # visualiser still draw — but paints it transparent so swww shows
      # through. Same call as Noctalia's wallpaper module being disabled.
      wallpaperEnabled = false;
    };

    # Point the picker at the shared wallpaper dir rather than its default
    # ~/Pictures/Wallpapers, which does not exist here.
    paths.wallpaperDir = "~/wallpapers";
  };

  shellSeedFile = pkgs.writeText "caelestia-shell-seed.json" (builtins.toJSON shellSeed);
in
{
  imports = [ caelestia.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    package = ouranosShell;
    cli = {
      enable = true;
      package = ouranosCli;
    };

    # The upstream module binds a systemd user service to
    # `wayland.systemd.target` (graphical-session.target). That target is
    # reached by EVERY Wayland session here, so leaving it on would start
    # Caelestia underneath waybar in the plain Hyprland session and again in
    # niri — two shells drawing two bars. The session owns its own shell, so it
    # is launched from the compositor autostart in compositor.nix instead
    # (shellKind = "caelestia"), which is session-scoped by construction. Same
    # reasoning as hyprsunset being a plain autostart rather than a unit.
    systemd.enable = false;

    # `settings` is deliberately left empty. The upstream module renders it to
    # xdg.configFile."caelestia/shell.json", i.e. a symlink into the read-only
    # store — but Caelestia's config is not a read-only input. Its settings UI
    # opens that exact path WriteOnly and rewrites the whole document on every
    # toggle (RootConfig::setupFileBackend in plugin/src/Caelestia/Config), so a
    # store symlink turns every change into a "Failed to save config" toast.
    # The file has to be a real, user-owned file; it is seeded below instead.
  };

  # Caelestia owns the GTK stylesheets. Its scheme applier writes gtk.css for
  # both GTK versions through atomic_write (utils/paths.py), i.e. os.replace —
  # which swaps out the *symlink itself*, silently stealing the file from
  # home-manager. Stylix declares the same two paths, so every rebuild after a
  # scheme apply hit checkLinkTargets and aborted the whole activation. Only
  # gtk.css is handed over; Stylix keeps settings.ini, which owns the theme,
  # icon, font and cursor names and which Caelestia never touches.
  xdg.configFile."gtk-3.0/gtk.css".enable = lib.mkForce false;
  xdg.configFile."gtk-4.0/gtk.css".enable = lib.mkForce false;

  # Seed shell.json and the scheme once, then leave both to Caelestia. Runs
  # after writeBoundary so home-manager has already unlinked the old store
  # symlink; the -L branch is the belt-and-braces case where an earlier
  # generation's link survives. Nothing overwrites an existing real file —
  # those files ARE the live state, rewritten wholesale by the shell (config)
  # and the CLI (scheme), so re-seeding would revert real choices on every
  # rebuild. Delete either file to fall back to these defaults.
  home.activation.caelestiaSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    caelestiaShell="${config.xdg.configHome}/caelestia/shell.json"
    if [ -L "$caelestiaShell" ]; then
      run rm -f $VERBOSE_ARG "$caelestiaShell"
    fi
    if [ ! -e "$caelestiaShell" ]; then
      run mkdir -p $VERBOSE_ARG "$(dirname "$caelestiaShell")"
      run install -m 0644 ${shellSeedFile} "$caelestiaShell"
    fi

    # Without this the CLI writes its own hardcoded fallback the first time it
    # runs against an empty state dir — catppuccin/mocha, whose mauve primary
    # is the colour this whole scheme exists to displace.
    caelestiaScheme="${config.xdg.stateHome}/caelestia/scheme.json"
    if [ ! -e "$caelestiaScheme" ]; then
      run mkdir -p $VERBOSE_ARG "$(dirname "$caelestiaScheme")"
      run install -m 0644 ${ouranosScheme}/scheme.json "$caelestiaScheme"
    fi
  '';
}
