{
  description = "open-agent-bridge — local A2A + MCP hub for Claude Code, OpenCode, Codex and agy";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        nodejs = pkgs.nodejs_22;
        pnpm = pkgs.pnpm;
      in
      {
        packages.open-agent-bridge = pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "open-agent-bridge";
          version = (builtins.fromJSON (builtins.readFile ./package.json)).version;
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: _:
              !(builtins.elem (baseNameOf path) [ "node_modules" "dist" ".open-agent-bridge" ]);
          };

          nativeBuildInputs = [ nodejs pnpm pkgs.pnpmConfigHook pkgs.makeWrapper ];

          pnpmDeps = pkgs.fetchPnpmDeps {
            inherit (finalAttrs) pname version src;
            inherit pnpm;
            fetcherVersion = 4;
            hash = "sha256-nbN9fgfn0QjoUAbHds5xLqorZO8QLmZfvKn5G/LamlQ=";
          };

          buildPhase = ''
            runHook preBuild
            pnpm run build:all
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/lib/open-agent-bridge $out/bin
            cp -r dist node_modules package.json $out/lib/open-agent-bridge/
            # Workspace link to dashboard/, whose build output already sits in dist/dashboard.
            rm $out/lib/open-agent-bridge/node_modules/.pnpm/node_modules/open-agent-bridge-dashboard
            for name in oab open-agent-bridge; do
              # tmux and ss back the Codex and Antigravity bridges.
              makeWrapper ${nodejs}/bin/node $out/bin/$name \
                --add-flags $out/lib/open-agent-bridge/dist/cli/index.js \
                --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.tmux pkgs.iproute2 ]}
            done
            runHook postInstall
          '';

          meta = {
            description = "Local agent communication hub (A2A + MCP + WebSocket)";
            homepage = "https://github.com/ooo-mmm/open-agent-bridge";
            license = pkgs.lib.licenses.mit;
            mainProgram = "oab";
          };
        });

        packages.default = self.packages.${system}.open-agent-bridge;

        apps.default = flake-utils.lib.mkApp { drv = self.packages.${system}.open-agent-bridge; };

        devShells.default = pkgs.mkShell {
          packages = [ nodejs pnpm ];
        };
      });
}
