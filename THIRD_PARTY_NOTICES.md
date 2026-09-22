# Third-party notices

## Rapfi

Gomoku embeds the Rapfi Gomoku/Renju engine in-process.

- Upstream: https://github.com/dhbloo/rapfi
- Pinned revision: `3c94c2a976f24a0dd1c5517623e9ab6fffe66bd7`
- License: GNU General Public License v3.0 or later
- License text: `Vendor/rapfi/Copying.txt`
- Corresponding upstream source: `Vendor/rapfi` (Git submodule)

This integration adds a small Objective-C++/C bridge but does not modify the
vendored Rapfi source. The iOS build currently uses Rapfi's built-in classical
evaluation; the separate `rapfi-networks` NNUE weight repository is not
bundled.

Rapfi's vendored dependencies retain their own notices and licenses inside the
Rapfi submodule. In particular, the embedded LZ4 sources are under the BSD
2-Clause license and SIMDe is distributed under its upstream permissive terms.

Distributing a binary that directly links Rapfi requires compliance with
Rapfi's GPLv3-or-later terms, including the applicable Corresponding Source
requirements. This notice records the integration and source pin; it is not a
substitute for distribution-specific legal review.
