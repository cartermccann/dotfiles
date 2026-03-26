{ ... }:
{
  flake.templates = {
    node = {
      path = ../templates/node;
      description = "Node.js + pnpm + TypeScript";
    };
    python = {
      path = ../templates/python;
      description = "Python 3 + uv";
    };
    elixir = {
      path = ../templates/elixir;
      description = "Elixir + Erlang/OTP";
    };
    zig = {
      path = ../templates/zig;
      description = "Zig";
    };
    go = {
      path = ../templates/go;
      description = "Go";
    };
    ruby = {
      path = ../templates/ruby;
      description = "Ruby";
    };
    java = {
      path = ../templates/java;
      description = "Java (JDK)";
    };
    c = {
      path = ../templates/c;
      description = "C/C++ with gcc, cmake, llvm";
    };
    rust = {
      path = ../templates/rust;
      description = "Rust (fenix stable)";
    };
    deno = {
      path = ../templates/deno;
      description = "Deno";
    };
  };
}
