# 破军参考图修订提示词

使用内置 imagegen；输入图 1 为用户补充的人物权威参考，输入图 2 仅提供旧版 8×4 行走排布参考。

```text
Use case: stylized-concept.
Asset type: production Godot 4 walking sprite sheet for the warrior character.
Input images: Image 1 is the authoritative character-identity and costume reference. Image 2 is layout and walking-direction reference only; do NOT preserve Image 2's older bearded face or sword-on-back design.
Primary request: Redraw the complete 8-column by 4-row walking sprite sheet using the exact young sword warrior appearance from Image 1.
Character lock: young adult male; clean-shaven face with NO beard and NO moustache; vivid chestnut/reddish-brown spiky swept hair; determined expression; dark navy/black plate armor with bright ornate gold trim and rounded pauldrons; red neck cloth and long red cape/scarf tails; blue-green gem at the chest; broad silver greatsword with gold/dark hilt. Keep body, face, hair, armor, cape, gem, and sword design consistent in all 32 cells.
Weapon rule: the greatsword is held in both hands in every walking frame, low and safely angled in front/alongside the body, NEVER sheathed or attached to the back. No attack effects, no slashing arc, no magic glow. Keep the same anatomical grip across front, side, and rear views.
Grid: exactly 8 equal columns and exactly 4 equal rows, exactly one complete character pose centered in every cell. Row 1 true front/down view. Row 2 true left-facing profile. Row 3 true right-facing profile. Row 4 true rear/up view with no face visible. No extra poses, merged cells, labels, numbers, dividers, borders, shadows, or ground.
Animation: each row is one seamless 8-frame natural human walking cycle: left contact, left weight/down, right-leg pass, right reach, right contact, right weight/down, left-leg pass, left reach. Show alternating planted/advancing feet and modest vertical body bob. Cape and hair follow motion subtly. No combat poses, crouching, kneeling, lying, idle duplicates, running, or floating.
Registration: identical scale in every cell; stable head and torso alignment; consistent foot baseline; enough transparent padding around sword tip, hair, cape and boots so nothing touches a cell boundary. Weapon motion restrained so it does not cross into adjacent cells.
Style: polished high-detail JRPG pixel-art sprite, matching Image 1's compact heroic proportions and palette; crisp hard pixel edges; no blur or painterly softness.
Background: genuinely transparent alpha, no checkerboard pattern baked into pixels, no scenery.
Output: a single clean 2:1 landscape sprite-sheet image only.
```
