# Campaign folders

CruS Online requires CruS Mod Loader and CruS Mod Base. Install a campaign under `user://campaigns/<folder>/` (the game's Godot user-data directory). The folder contains one `campaign.json` and one subfolder per stage. Existing single missions in `user://levels/` continue to appear under **Custom Missions**. The built-in game appears under **Cruelty Squad**.

`campaign.json` declares the campaign's identity, display name, version, and ordered stages:

```json
{
  "id": "my_campaign",
  "name": "My Campaign",
  "version": "1.0",
  "levels": [
    {"id": "01", "folder": "01", "index": 0, "unlock_after": [], "secret": false},
    {"id": "02", "folder": "02", "index": 1, "unlock_after": ["01"], "secret": false}
  ]
}
```

Each stage subfolder contains a Modbase-style `level.json`, its scene, and any image or other files that level references. The `level_scene` and `image` fields are resolved against that stage folder. Every stage needs a unique `id`, folder, and level `name`. `index` determines menu order; `unlock_after` lists stage IDs that must be completed before selection. Locked stages remain hidden until unlocked. Campaign completion is stored separately for each save slot. The sample [Placeholder campaign](../custom_missions/Placeholder/campaign.json) has five regular Hilton Hitjob stages followed by three secret stages.

When hosting online, the campaign folder is included as one content group. Joining players can install or update the whole group before the automatic restart and rejoin.
