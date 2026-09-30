# Art credits

Every texture and sky image in the realistic look is **CC0** (public domain): free to use, modify and redistribute, no attribution required. Credited here anyway.

Source files live in `art/` (Blender reads them when it builds a level); the Godot copies are generated from them.

## Textures (ambientCG, CC0)

1K JPG sets, maps kept: Color, NormalGL, Roughness, Metalness (where the set has one).

| Set | Used for | Source |
|---|---|---|
| Concrete046 | plaza and concrete surfaces | https://ambientcg.com/view?id=Concrete046 |
| Concrete044D | walls, rough and dark concrete | https://ambientcg.com/view?id=Concrete044D |
| Asphalt031 | paths and roads | https://ambientcg.com/view?id=Asphalt031 |
| Wood094 | ramp surfaces and ramp sides (darkened) | https://ambientcg.com/view?id=Wood094 |
| Metal032 | coping, rail posts, ledge edges | https://ambientcg.com/view?id=Metal032 |
| PaintedMetal004 | painted rails and handrails | https://ambientcg.com/view?id=PaintedMetal004 |
| Grass004 | lawns | https://ambientcg.com/view?id=Grass004 |

Licence: https://docs.ambientcg.com/license/

## Sky (Poly Haven, CC0)

| HDRI | Used for | Source |
|---|---|---|
| Qwantani Late Afternoon (Pure Sky), 2K for baking, 1K in the game | sky, sky light, sun direction | https://polyhaven.com/a/qwantani_late_afternoon_puresky |
| Qwantani Mid Morning (Pure Sky), 2K for baking, 1K in the game | Maple Grove Elementary's sky, sky light, sun direction | https://polyhaven.com/a/qwantani_mid_morning_puresky |

Licence: https://polyhaven.com/license

## Characters (MakeHuman / MPFB, CC0)

Built by `blender/character.py` with **MPFB** (MakeHuman for Blender, installed from extensions.blender.org) from the MakeHuman **CC0** asset packs. MakeHuman's base mesh and targets and these packs are CC0, so the exported characters are CC0 too; the MPFB add-on itself is GPL but is a build tool and is not shipped.

| Pack | Used for | Source |
|---|---|---|
| makehuman_system_assets | base skins, eyes, eyebrows, eyelashes | https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html |
| shirts01, pants01, shoes01 | clothing (The Dev: male_casualsuit02, shoes06) | https://static.makehumancommunity.org/assets/assetpacks/ |
| hair01, hats01 | hair (The Dev: short02), hats | https://static.makehumancommunity.org/assets/assetpacks/ |

Community assets from the MakeHuman asset library, by their authors (licence as stated in each asset's file):

| Asset | Author | Licence | Worn by |
|---|---|---|---|
| toigo_inverted_bob, toigo_ankle_boots_female, toigo_basic_tucked_t-shirt, toigo_fisherman_sweater, toigo_mj_cloth_shoes, toigo_wool_pants | MRT | CC0 | the principal, The Vlogger, The Dad, guests, kids |
| cortu_cargo_pants, cortu_jeans_shorts | Cortu Johnstone | CC0 | The Vlogger, kids |
| namuhekam_male_polo_shirt | Namuhekam | CC0 | The Dad, the grandpa |
| elvs_crude_t-shirt_male | MakeHuman, edited by Elvaerwyn | CC0 | the birthday kid |
| culturalibre_hair_05 | culturalibre | CC0 | The Actor |
| braid01 | MakeHuman team (released as CC0 in September 2020) | CC0 | Leo's mom |

Every character asset that ships is CC0, which sits fine beside the MIT-licensed code. Two hairstyles that used to be in the cast were swapped out on 2026-09-30 because their files say AGPL3: culturalibre_hair_02 (The Actor) and rehmanpolanski_hair_bun_brown (Leo's mom). MakeHuman made its own assets CC0 by default in 2020, but it cannot relicense a third party's upload, and its old CC0 exception covered only exports from the official MakeHuman application, not MPFB. When adding clothes or hair, check the `license` line in the asset's `.mhclo` and keep to CC0.

Licence: https://www.makehumancommunity.org/content/license_explanation.html

## Font (SIL Open Font License)

| Font | Used for | Source |
|---|---|---|
| Barlow Condensed (Medium, Bold, ExtraBold), The Barlow Project Authors | all UI text | https://github.com/jpt/barlow |

The font is **not** CC0: it is under the SIL Open Font License 1.1 (`game/assets/fonts/ofl.txt`), which allows bundling it with the game; it must keep its licence and cannot be sold on its own.
