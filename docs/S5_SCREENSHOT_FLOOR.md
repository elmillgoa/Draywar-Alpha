# S5 — Screenshot / Steam-page floor (honest inventory)

**Date:** 2026-08-03  
**Phase:** S5 ship layer (code). Presentation still tech-demo gray-box.

Wishlists need months. This is what a stranger sees **today** if you grab a
Steam capsule frame — and what still has to change before a page looks shippable.

## What still looks gray-box

| Area | Reality now |
|------|-------------|
| **Player ship** | Code-built mesh (boxes/prisms): hauler gold wings vs fighter steel fin. Unshaded materials. Readable silhouette at combat range, not art. |
| **Hostiles** | Red capsule + fins. Profile colour variants only. No faction skins. |
| **Traffic** | Soft freighter / patrol colours. Same primitive language as combat ships. |
| **Stations / gates** | Unshaded cylinders, discs, rings. System tint on station colour + sky only. |
| **Backdrop** | Procedural starfield + far planet/moon/sun disc meshes (E6.2). Not painted skyboxes. |
| **Belt rocks** | Simple spheres where belts exist (Gamma sparse, Epsilon denser). |
| **Weapons VFX** | Yellow player bolts / red hostile bolts. Short muzzle flash. No trails, no impact FX pack. |
| **UI** | B1 theme (readable, not polished). Station menu is a tall scroll of sections. HUD is text + combat reticle/brackets/pip. |
| **Outfitting (new S5)** | Buttons and labels in station Services → **Outfitting**. No 3D hangar, no item icons — pure function list. |
| **Audio** | No production SFX/music floor for Steam trailer. |
| **Logo / key art** | None in-engine. |

## What is already “readable enough” for a tech slice

- Cool / warm / sickly system identity (Alpha / Beta / Gamma and new spurs).
- Hauler vs Fighter silhouette difference when switching hulls.
- Lock brackets + lead pip so combat screenshots show *intent*, not just flying.
- Sector map + station trade rows with quantity (S2) — economic fantasy is
  visible in UI even when meshes are gray.

## What Steam page needs before “looks like a game”

Pulled forward from S10 presentation track — **not done in S5 code**:

1. **Ship materials + at least one hero screenshot pose** (lit, not pure unshaded flat).
2. **Station exterior pass** (even one dock family) so Alpha Port is not a barrel.
3. **Weapon hit/muzzle pack** so combat stills pop.
4. **UI chrome pass** (panel, fonts, icon row for outfit/trade) — screenshot test.
5. **Key art / logo** outside the engine.

## Perf note (S5)

- Budget stays **20 ships**. Densest layout = contested traffic + max hostiles + player.
- `PerfProbe` samples FPS for evidence; CI only checks the instrument works.
- Do **not** raise the ship budget without a measured densest-scene run on target hardware.

## Session A status

Ship layer **code** can show progression (buy fighter, install weapons/racks).
Presentation floor for capsule art is **still open** — track in S5–S6 window,
not only S10.
