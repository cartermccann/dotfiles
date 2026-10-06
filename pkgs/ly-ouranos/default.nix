{
  runCommand,
  python3,
  ly,
}:
# Ly greeter assets in Portfolio2's language (see modules/desktop-wayland.nix):
#
#   ouranos.dur  the CM/26 monogram resolving coarse -> sharp (make-dur.py)
#   ouranos.ini  a language file: Ly's English strings with slash-pair labels
#                ("01 / USER"); every key is kept so Ly's parser finds them all
runCommand "ly-ouranos" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out
  cp ${./monogram.py} monogram.py
  PYTHONPATH=. python3 ${./make-dur.py} $out/ouranos.dur

  sed \
    -e 's|^login = .*|login = 01 / USER|' \
    -e 's|^password = .*|password = 02 / PASS|' \
    -e 's|^shutdown = .*|shutdown = / SHUTDOWN|' \
    -e 's|^restart = .*|restart = / REBOOT|' \
    -e 's|^sleep = .*|sleep = / SLEEP|' \
    -e 's|^authenticating = .*|authenticating = AUTH / ...|' \
    -e 's|^logout = .*|logout = SESSION / ENDED|' \
    ${ly.src}/res/lang/en.ini > $out/ouranos.ini
''
