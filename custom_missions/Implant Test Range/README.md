# Implant Test Range

Install this folder in `user://levels/Implant Test Range` (the Cruelty Squad
Godot user-data directory). It contains a playable flat `.tscn` mission and a
small TrenchBroom `.map` source with a player spawn, Practice Reflex pickup,
and F2500-armed hostile SWAT officer. The `.tscn` is the shipped playable
version; rebuilding from the `.map` may replace its hand-authored lighting,
navigation mesh, and positions.

The mission's `required_implants` and `required_weapons` fields are checked by
CruS Online's Mod Base level verifier. The Practice Reflex definition names
this mission as its `source_level`; it is registered only while this mission
and its matching dependency declaration are installed. The level also requires
the F2500 weapon. This example remains test content rather than a campaign
mission.
