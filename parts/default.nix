let
  entries = builtins.readDir ./.;
  isNixFile =
    name: entries.${name} == "regular" && builtins.match ".*\\.nix" name != null && name != "default.nix";
  isSubdir = name: entries.${name} == "directory";
  nixFiles = builtins.filter isNixFile (builtins.attrNames entries);
  subdirs = builtins.filter (
    d: isSubdir d && builtins.pathExists (./${d}/default.nix)
  ) (builtins.attrNames entries);
in
{
  imports = map (f: ./${f}) nixFiles ++ map (d: ./${d}) subdirs;
}
