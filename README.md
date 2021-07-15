# [NMRiH] Better Tools
This plugin seeks to make tools a bit more interesting by expanding their functionality.

## Requirements:
- Sourcemod 1.11 or higher

## Details:

### Fire Extinguisher
- Extinguish dynamic fires by pointing the hose at them. Supported:
  - Molotov fires
  - Burning props
  - Burning NPCs
  - Burning players.
- ~~Slow zombies down by blasting them with the hose~~ (Soon)

CVars:
- sm_extinguisher_tweaks (Default: 1) - Toggle fire extinguisher tweaks on and off
- sm_extinguisher_use_time (Default: 2) - Seconds it takes to extinguish an entity

### Barricade Tool
Recollect healthy boards from barricades by hitting them with the barricade tool.
(This is extracted from QOL by Ryan)

CVars:
- sm_barricade_tweaks (Default: 1) - Toggle barricade tweaks on and off

### Zippo
- Ignite entities by stretching your arm out with a lit zippo. Supported:
  - Explosive props
  - Wooden breakables.
  - NPCs
  - Other players.

CVars:
- sm_zippo_tweaks (Default: 1) - Toggle zippo tweaks on and off
- sm_zippo_use_time (Default: 2) - Seconds it takes the zippo to ignite an entity
- sm_zippo_ignites_zombies (Default: 1) - Whether the zippo can ignite zombies
- sm_zippo_ignites_props (Default: 1) - Whether the zippo can ignite breakable wooden props and explosives
- sm_zippo_ignites_humans (Default: 0) - Whether the zippo can ignite players (abides by friendly fire and infection rules)


## Config
All settings are saved to cfg/sourcemod/plugin.nmrih-bettertools.cfg
