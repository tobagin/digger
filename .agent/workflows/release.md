---
description: How to release a new version of Digger
---

1. Bump version in `meson.build` and `packaging/digger.spec`.
2. Update `CHANGELOG.md` (new `## [X.Y.Z] - YYYY-MM-DD` section).
3. Add a `<release>` entry at the top of `<releases>` in
   `data/io.github.tobagin.digger.metainfo.xml.in`.
4. If updating bundled deps, edit both Flatpak manifests
   (`packaging/io.github.tobagin.digger.yml` and `*.Devel.yml`): update each
   `url` and recompute `sha256` (`curl -sL <url> -o /tmp/s && sha256sum /tmp/s`).
   Keep `runtime-version` in sync. Do NOT bump `bind-dig` past 9.16.x without a
   build rework (OpenSSL becomes mandatory).
5. Point the production manifest `digger` git source at `tag: vX.Y.Z`.
6. Verify: `./scripts/build.sh --dev`
7. Commit changes:
   `git add . && git commit -m "Release version X.Y.Z"`
8. Tag release:
   `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
9. Push:
   `git push origin HEAD --tags`
10. Add the pushed commit SHA to the production manifest `digger` source
    `commit:` field and submit/refresh the Flathub PR.
