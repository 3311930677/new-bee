# Three roles: direct video v19

Each direction uses a consecutive source range at the original 24 FPS. No generated images, optical-flow interpolation, reversed frames or mirrored directions. Background removal, uniform camera registration and nearest-neighbor resize only. The original videos have no dedicated four-direction stationary shots; idle holds a narrow, grounded pose copied exactly from that character's own walk cycle.

Source ranges, timestamps, crop bounds, registration and RGBA hashes are in each role's runtime_source_checks.json. Previous resource bindings are backed up beside it. The fs assets and its 7 FPS front/back playback are preserved.
