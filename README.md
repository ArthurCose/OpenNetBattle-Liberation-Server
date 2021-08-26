# ONB Liberation Server

## Abilities

Check out `scripts/main/liberations/ability.lua`

You can create abilities by adding them to the `Ability` table and associate abilities to navis using the `navi_ability_map`

## Enemies

Take a look at `scripts/main/liberations/enemy.lua`.
The top of the file explains the expected variables on enemy classes, adding new enemies is done by associating a name to your class in the `name_to_enemy` table.
Anything more can be resolved by taking a look at existing enemies in `scripts/main/liberations/enemies`.

## Panel Encounters

Take a look at `PanelEncounters` in `scripts/main/liberations/panel_encounters.lua`

## Creating Maps

### Map Custom Properties

Target: number

- The amount of phases it should take one player to complete this map

### Objects

Spawn:

- Players will spawn at this point

Point of Interest:

- Player cameras will follow these points in order of creation/id on join
- Name: Point of Interest

Dark Holes

- Third tile in /server/assets/tiles/panels.tsx
- Custom Properties:
  - Spawns: string
    - BigBrute
  - Direction: string
    - Up Left
    - Up Right
    - Down Left
    - Down Right

Dark Panels:

- First tile in /server/assets/tiles/panels.tsx
- Can spawn a boss
- Custom Properties:
  - Boss?: string
    - BlizzardMan
  - Direction?: string
    - Up Left
    - Up Right
    - Down Left
    - Down Right

## Running the server

Launch with `--custom-emotes-path="/server/assets/custom emotes.png"`
