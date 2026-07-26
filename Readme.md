# Description

Activate alchemy apparatus in-world - no need to go into your inventory! Allows brewing potions using ingredients from
inventory and nearby containers. Supports ingredients from Corporeal Carryable Containers.
New Alchemy Window shows a lot of additional info and offers new functionality:

- all effect icons at a glance, with matching ones being highlighted
- created effect list can show full final stats of a potion (see settings, off by default)
- can switch to "Poison" mode that flips apparatus function for harmful and positive effects - very useful if you have
  mods that can apply poisons.
- default potion name can have prefix - separate for potion and poison (see settings, off by default)
- effect list for easy filtering of ingredients
- effects in the list by default filtered by potion type - only positive for potions, harmful for poisons
- effects can be marked as favorite

# Reworked Effect Discovery

Can be turned on in options. Requires Inventory Extender for tooltip changes. Changes from vanilla:
Alchemy skill does not grant potion effect knowledge
Drinking any potion reveals all of its effects
Store-bought potions with positive effects will show all positive effects
Store-bough potions without positive effects will show all effects
Self-brewed potions will show effects that are known from at least 1 ingredient
Every 5 (configurable) successfully brewed potions with same ingredients will reveal next unknown effect
Ingredients still reveal effects with Alchemy skill levels, but slower (configurable)
Ingredients reveal next effect above skill limit when consumed
Ingredients also reveal all known effects from brewed potion
Note: currently there is no way to modify in-world tooltips. Waiting on tooltips de-hardcoding hopefully in OpenMW 0.52.

# Credits
- [sbelmont85](https://www.nexusmods.com/profile/sbelmont85) - for [Alchemist's Journal](https://www.nexusmods.com/morrowind/mods/59538) integration and lots of PRs with fixes and UI improvements.
- [Ralts](https://www.nexusmods.com/profile/therealralts) - for the amazing [Inventory Extender](https://www.nexusmods.com/morrowind/mods/59205) - parts of the UI code are taken from it.
- [mym](https://www.nexusmods.com/profile/mym) - for [Skill Evolution](https://www.nexusmods.com/morrowind/mods/57802) integration.
- [DaisyHasACat](https://www.nexusmods.com/morrowind/users/790766) - for the amazing [Tabletop Alchemy](https://www.nexusmods.com/morrowind/mods/52891) that partially inspired this mod.
