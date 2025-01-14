# terranix library
# ----------------
# in here are all the code that is terranix

{ stdenv, writeShellScriptBin, writeText, pandoc, ... }:
let
  usage = writeText "useage" ''
    Usage: terranix [-q|--quiet] [--trace|--show-trace] [path]
           terranix --help

      -q | --quiet   dont print anything except the json

      -h | --help    print help

      --trace        show trace information if there is an error
      --show-trace

      path           path to the config.nix

    '';
in {


  terranix = writeShellScriptBin "terranix" /* sh */ ''

  QUIET=""
  TRACE=""
  FILE="./config.nix"

  while [[ $# -gt 0 ]]
  do
      case $1 in
          --help| -h)
              cat ${usage}
              exit 0
              ;;
          --quiet | -q)
              QUIET="--quiet"
              shift
              ;;
          --show-trace | --trace)
              TRACE="--show-trace"
              shift
              ;;
          *)
              FILE=$1
              shift
              break
              ;;
      esac
  done

  if [[ ! -f $FILE ]]
  then
      echo "$FILE does not exist"
      exit 1
  fi

  TERRAFORM_JSON=$( nix-build \
      --no-out-link \
      --attr run \
      $QUIET \
      $TRACE \
      -I config=$FILE \
      --expr "
    with import <nixpkgs> {};
    let
      terranix_data = import ${toString ./core/default.nix} { terranix_config = { imports = [ <config> ]; }; };
      terraform_json = builtins.toJSON (terranix_data.config);
    in { run = pkgs.writeText \"config.tf.json\" terraform_json; }
  " )

  if [[ $? -eq 0 ]]
  then
      cat $TERRAFORM_JSON
  fi

  '';

  manpage = version: stdenv.mkDerivation rec {
    inherit version;
    name = "terranix-manpage";
    src = ./doc;

    installPhase = ''
      mkdir -p $out/share/man/man1

      cat <( echo "% terranix" && \
        echo "% Ingolf Wagner" && \
        echo "% $( date +%Y-%m-%d )" && \
        cat $src/man_*.md ) \
        | ${pandoc}/bin/pandoc - -s -t man \
        > $out/share/man/man1/terranix.1
    '';

  };


}
