# Reference art completion, 2026-10-11

User-authorized scope: complete remaining town/field art, original facilities/NPC/quest/exit integration, map consistency and save migration, loading/title/login redesign, captures and regression. Preserve the existing hero. Match terrain's fine pixel density to the hero; avoid undersized whole-map artwork scaled up. Signpost exit, left/right buildings, independent foliage and natural fading southern ground remain authoritative.

Work stages:

- [x] Generate and inspect fine ground materials; bake 2x-density runtime chunks. Scene trials are retained but not deployed.
- [x] Complete eight facilities, visitor ledger, construction and nine NPCs.
- [x] Export native sprites, complete-foot anchors, matching portraits and original-generation provenance.
- [x] Integrate real town/field data, terrain, decor, facilities and NPCs.
- [x] Repair river/bridge geometry, navigation and old-position migration.
- [x] Rebuild loading/title/login with real progress and existing callbacks.
- [x] Capture real scenes, scale comparisons and state shots.
- [x] Run 15 relevant regression cases and 173 integration checks; prepare Claude review package.

Existing prototype is not formal-game delivery. Do not reuse the rejected 3D batches or upscale the 945x1663 town terrain as final art. Retain originals; any source resolution differences must be logged. Final pixel-grid/art quality and Android hardware are distinct from desktop functional checks.
