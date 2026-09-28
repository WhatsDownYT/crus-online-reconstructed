Custom missions use the optional CruS Mod Base. Online still works without it.

To try Hilton Hitjob:

1. Close the host's game. Copy the built `CruS Mod Base` folder from `dist/optional` into `%APPDATA%\Godot\app_userdata\Cruelty Squad\mods`.
2. Extract `E:\Cruelty\Extensions\hiltonhitjob.zip` directly into `%APPDATA%\Godot\app_userdata\Cruelty Squad\levels`. The map should be at `levels\Hilton Hitjob\level.json`, with no extra folder between `levels` and `Hilton Hitjob`.
3. Start the game and host a lobby. In Level Select, click the down arrow after the normal mission squares, select Hilton Hitjob's portrait, then start the mission once everyone has joined. The up arrow returns to normal missions.
4. A friend with the same Online build can join without manually installing Modbase or the map. The popup lists the host's mods and missions. **Install and join** downloads and verifies them, restarts the game, and rejoins. **Cancel**, or closing the popup, stops the join.

The host shares active loader mods and registered custom missions. Clients with matching files join immediately. Extra active client mods are listed for disabling; their files stay installed. Replaced versions are kept in `user://online-content`.

Modbase's console, noclip and debug editing are blocked online. Its ordinary singleplayer tools remain available. Online's host and operator commands keep their existing permissions. This blocks Modbase's built-in cheats, rather than trying to detect arbitrary modified clients.

The native tests cover the supplied Loader, Modbase and Hilton Hitjob: cancellation, downloads, file verification, an actual executable restart, automatic LAN rejoin, targets, results, and blocked cheat handlers. Steam's content packet permissions and handling across scene changes are also checked. A two-account Steam download still needs a live test.

The guarded Modbase scripts come from [CruS Mod Base](https://github.com/CruS-Modding-Infrastructure/crus-modbase). Loader and Modbase remain separate projects; Online supplies the compatibility changes.
