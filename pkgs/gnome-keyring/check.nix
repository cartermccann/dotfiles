{
  runCommand,
  stdenv,
  pkg-config,
  glib,
  dbus,
  python3,
  gnome-keyring,
  expectCrash ? false,
}:
runCommand "gnome-keyring-client-race-check"
  {
    nativeBuildInputs = [
      stdenv.cc
      pkg-config
    ];
    buildInputs = [ glib ];
  }
  ''
    cc -Wall -Wextra -Werror ${./stress.c} -o stress $(pkg-config --cflags --libs gio-2.0)
    ${python3}/bin/python3 ${./check.py} \
      ${gnome-keyring}/bin/gnome-keyring-daemon \
      ${dbus}/bin/dbus-daemon "$PWD/stress" \
      ${if expectCrash then "crash" else "survive"} | tee "$out"
  ''
