# [NMRiH] Better Tools
This plugin seeks to make tools a bit more interesting by expanding their functionality.



https://user-images.githubusercontent.com/11559683/125731141-2a610451-4280-4e6e-ac4a-d5bb26559e67.mp4


## Requirements:
- Sourcemod 1.11 or higher

## Details:

![fireext](https://user-images.githubusercontent.com/11559683/125731198-f5c06074-fa1e-48f4-b036-4320c77c9a32.png)

- Extinguish dynamic fires by pointing the hose at them. Supported:
  - Molotov fires
  - Burning props
  - Burning NPCs
  - Burning players.
- ~~Slow zombies down by blasting them with the hose~~ (Soon)

![barr](https://user-images.githubusercontent.com/11559683/125731183-638b67d3-edcb-40b3-98a5-6c1491209cb4.png)

- Recollect healthy boards from barricades by hitting them with the barricade tool 
(This is extracted from QOL by Ryan)


![zip](https://user-images.githubusercontent.com/11559683/125731240-9bbd39c8-de35-409e-a790-38d7aec6b41b.png)
- Ignite entities by stretching your arm out with a lit zippo. Supported:
  - Explosive props
  - Wooden breakables.
  - NPCs
  - Other players.


## ConVars

All configuration variables are saved to `cfg/sourcemod/plugin.nmrih-bettertools.cfg`

- sm_extinguisher_tweaks (Default: 1) - Toggle fire extinguisher tweaks on and off
- sm_extinguisher_use_time (Default: 2) - Seconds it takes to extinguish an entity

- sm_barricade_tweaks (Default: 1) - Toggle barricade tweaks on and off 


- sm_zippo_tweaks (Default: 1) - Toggle zippo tweaks on and off
- sm_zippo_use_time (Default: 2) - Seconds it takes the zippo to ignite an entity
- sm_zippo_ignites_zombies (Default: 1) - Whether the zippo can ignite zombies
- sm_zippo_ignites_props (Default: 1) - Whether the zippo can ignite breakable wooden props and explosives
- sm_zippo_ignites_humans (Default: 0) - Whether the zippo can ignite players (abides by friendly fire and infection rules)
