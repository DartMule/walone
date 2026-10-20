# Copyright and third-party notices

Required Notice: Copyright (c) 2026 DartMule and Walone contributors.

The original Walone source code, documentation and original artwork are provided
under the [PolyForm Noncommercial License 1.0.0](LICENSE.md).
This license does not replace or restrict the licenses of third-party material.
Contributors retain copyright in their contributions.

## Audio and bundled resources

The audio recordings in `assets/` and `tool/resource_sources/` are separately
licensed. Their authors, source revisions, modifications and licenses are listed
in [SOURCES.md](assets/licenses/SOURCES.md) and the accompanying manifests.
License texts are included in both resource directories. These include MIT,
GPL-2.0, GPL-3.0, CC0 1.0, CC BY 3.0, CC BY 4.0 and public-domain material.
Original recordings and extraction instructions are retained with the sources.

The noncommercial restriction on original Walone code does not add restrictions
to these third-party recordings. Reusing those recordings independently is
governed by their own licenses.

## Software dependencies

Dart and Flutter dependency versions are recorded in `pubspec.lock`.
Their upstream licenses remain applicable; Flutter includes the dependency
license registry in its built application resources.

macOS updates use Sparkle 2.10.0 under its MIT license and the additional
notices in the [Sparkle license](docs/licenses/Sparkle-LICENSE.txt).
The release tool includes Walone and Sparkle notices inside the signed app.

Import tools such as yt-dlp, FFmpeg and Deno are downloaded separately when
requested. Their own licenses and upstream distribution terms apply.
