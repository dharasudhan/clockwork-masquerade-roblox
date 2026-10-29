# Creator Store model shortlist — to vet (Oct 29 2026)

v1.0 uses **no Creator Store models**: every part is built by script. This is a shortlist of *kinds* of free
models worth looking at in a later art pass. **No asset ids were verified** — search the Creator Store in Studio
(Toolbox → Creator Store → Models, filter "Verified creators" / free) and vet each pick with the rules below.

| Need | Search terms | Why | Budget |
|---|---|---|---|
| Chandeliers / wall sconces | "victorian chandelier", "brass sconce" | replace the cylinder chandeliers in Ballroom, Dining Hall | ≤ 30 parts or 1 MeshPart each |
| Bookshelves with books | "library bookshelf mesh" | Library, Study, Drafting Loft | MeshPart, no scripts |
| Grand piano | "grand piano mesh" | Music Room | 1–3 MeshParts |
| Billiard table | "pool table mesh" | Billiard Room | ≤ 5 parts |
| Boiler / furnace / pipes | "steampunk boiler", "industrial pipes" | B1 Boiler Room, Pump Room | MeshParts |
| Telescope | "brass telescope" | Observatory Dome (Tower) | ≤ 5 parts |
| Gears / clock faces | "steampunk gear mesh", "clock face" | Great Clock Room, Clock Workshop | reuse 1 mesh, recolour |
| Automaton / mannequin | "robot mannequin", "clockwork robot" | Automaton Nursery (Attic) | static, no rig scripts |
| Lantern (held) | "lantern mesh" | held lantern + cosmetic variants | 1 MeshPart + PointLight |

## Vetting rules (must pass all)
1. **No scripts** inside the model (delete any Script/LocalScript/ModuleScript; reject if it needs one). Backdoor risk.
2. Creator is Roblox or a verified creator, or the model is clearly marked free-to-use; note creator + asset id in
   `game/CREDITS.md` → Art.
3. Fits the look: 1920s inventor / brass + teal + violet, **no ghosts, skulls or horror**.
4. Part budget: the map is already ~3,540 parts; any model must replace script parts, not add net parts.
5. Collisions off for decor (bots and walkers must not snag), CastShadow off except hero lights.
6. Test with StreamingEnabled (model must be fine as Default/Nonatomic; only interactables are Persistent).
