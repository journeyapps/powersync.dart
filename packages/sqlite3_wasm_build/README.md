This directory includes tools to build `sqlite3.wasm` files compatible with the
PowerSync Dart SDK.

This build process is adapted from [`package:sqlite3`][upstream], with patches
applied to link the [PowerSync SQLite extension][core] statically.

### Working on patches

To adapt the patches:

1. Clone `https://github.com/simolus3/sqlite3.dart.git` somewhere.
2. Apply the existing patches to your clone: `git apply patches/*`.
3. Rebase onto a new upstream release if necessary.
4. Obtain a new patchset with `git format-patch upstreamref..HEAD`.

[upstream]: https://github.com/simolus3/sqlite3.dart/tree/main/sqlite3/assets/wasm
[core]: https://github.com/powersync-ja/powersync-sqlite-core
