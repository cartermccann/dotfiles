#!/usr/bin/env python3
"""Generate a Caelestia colour scheme from the Ouranos cobalt accent.

Caelestia resolves a named scheme by reading
`<cli-package>/data/schemes/<name>/<flavour>/<mode>.txt` — a flat "key value"
file of ~120 Material 3 roles. Those files ship inside the CLI package, so a
house scheme has to be generated at build time and grafted in (see
home/hyprland/caelestia.nix).

Rather than hand-mapping Base16 slots onto M3 roles, this calls Caelestia's own
`gen_scheme` — the same function behind `caelestia scheme set --name dynamic` —
with a fixed seed instead of a colour scored out of the wallpaper. That keeps
the key set exactly in step with whatever the pinned CLI expects, including the
terminal ramp, the Catppuccin-compatible aliases and the KDE roles.

M3 re-tones the seed for contrast, so `primary` comes out lighter than the seed
(#3b6bff at tone 50 becomes ~#b6c4ff at tone 80 in dark mode). The *hue* is
carried through exactly, which is what makes the result read as cobalt.

Emits `dark.txt` and `light.txt` for the package graft, plus a `scheme.json`
that home-manager seeds into ~/.local/state/caelestia so a fresh state dir
starts on Ouranos rather than the CLI's hardcoded catppuccin-mocha fallback.

Usage: caelestia-ouranos-scheme.py <seed-hex> <name> <flavour> <variant> <outdir>
"""

import json
import sys
from pathlib import Path

from caelestia.utils.material.generator import gen_scheme, hex_to_hct


class Seed:
    """The subset of caelestia.utils.scheme.Scheme that gen_scheme reads.

    Constructing the real Scheme would touch ~/.local/state, which is not
    available inside the build sandbox.
    """

    def __init__(self, mode: str, variant: str, flavour: str) -> None:
        self.mode = mode
        self.variant = variant
        self.flavour = flavour


def main() -> int:
    if len(sys.argv) != 6:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2

    seed, name, flavour, variant = sys.argv[1:5]
    outdir = Path(sys.argv[5])
    outdir.mkdir(parents=True, exist_ok=True)

    generated = {}
    for mode in ("dark", "light"):
        # gen_scheme only reads `flavour` to decide whether to apply its "hard"
        # surface darkening, which we do not want: the standard surfaces
        # already land on the Ouranos near-black ground (#11131b against the
        # palette's #0a0c11), and hard drops them to near-#000.
        colours = gen_scheme(Seed(mode, variant, flavour), hex_to_hct(seed.lstrip("#")))
        generated[mode] = colours
        body = "".join(f"{key} {value}\n" for key, value in colours.items())
        (outdir / f"{mode}.txt").write_text(body)

    (outdir / "scheme.json").write_text(
        json.dumps(
            {
                "name": name,
                "flavour": flavour,
                "mode": "dark",
                "variant": variant,
                "colours": generated["dark"],
            }
        )
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
