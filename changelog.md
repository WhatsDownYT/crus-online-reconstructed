CRUS REVITALIZED FULL CHANGELOG



**SINGLEPLAYER AND ONLINE**



- Separated Singleplayer and Online. Offline missions use the normal game flow instead of starting a local multiplayer server, and Online menus, synchronization screens, voice input, and session controls remain separate from Singleplayer
- Expanded both Steam and LAN multiplayer around shared mission rules and progression. Leaving a session, losing the connection, or having the host close the lobby restores normal menu control



**LOBBIES AND JOINING**



- Rebuilt the public Steam lobby browser to show lobby names, gamemodes, player counts, capacity, and estimated ping. Players can select a lobby and press Join or double-click it, with a Refresh button for requesting an updated list. Lobby information updates when Steam delivers it, and previously found lobbies are checked before being removed when a search misses them
- Added customizable lobby names, defaulting to the host's Steam name, and Public, Friends Only, and Private lobby types. Friends Only supports joining through Steam friends, while Private lobbies can be joined through a code or Discord invite
- Replaced lobby passwords with six-character alphanumeric lobby codes. Direct Join accepts codes for all three Steam lobby types, and a lobby's code stays hidden until its display is clicked
- Added configurable lobby capacity, supporting up to 250 players on Steam and 4096 on LAN, including the host. Public searches filter out unrelated CruS Online lobbies and incompatible Revitalized builds
- Reworked connection handling so the game waits for a successful connection before entering the lobby interface. Connecting uses the full-screen synchronization presentation with a Connecting label. Invalid codes, canceled attempts, full lobbies, closed sessions, and failed connections return control to the appropriate menu
- Reorganized hosting and joining around the Main Online tab. Host settings become available after choosing Steam or LAN and can be changed while a lobby is active. The player list shows host status, readiness, speaking status, and mute information
- Added a Ready button for non-hosts in level select and a Ready: #/# count for hosts. Clients see the host's selected mission and its handler information beside Ready, with live selection updates and no client control over Punishment or Chaos. Online missions require at least two players, and unavailable starts explain their restrictions through tooltips



**ONLINE MODES**



- Expanded the original multiplayer sandbox into campaign play, last-survivor Deathmatch, and Counter-Opps, with separate mission rules, results, and win conditions
- Reworked Deathmatch around players spawning across civilian and fallback locations instead of sharing the normal spawn. The last living player wins, and the host can choose whether enemies and civilians remain in the mission. Results name the winner and omit NPC statistics when NPCs are disabled
- Added Counter-Opps, with Operatives completing the mission while Counter-Operatives oppose them alongside hostile NPCs. Counter-Operatives spawn around civilian locations, and the mode has team-specific revival rules, victory messages, and settings for enemy friendly fire and retaliation
- Counter-Opps teams can be chosen by players, assigned by the host, or randomized each round with balanced player counts. Host overrides disable random assignment, and a match cannot start without opposing teams. CSHQ and Trauma Loop are unavailable in this mode and display red mission portraits with restriction tooltips
- Deathmatch and Counter-Opps allow all difficulty doors to open and remove preplaced weapon and implant pickups. Their wins and losses are tracked separately, and player departures are accounted for when deciding who remains in the match



**MISSION FLOW, OBJECTIVES, AND PROGRESSION**



- Reworked Online mission starts, loading, restarts, exits, failures, and results as shared host-directed events. The synchronization screen shows how many players have loaded, and host-directed transitions keep the lobby in the same mission or ending cutscene
- Expanded mission objective synchronization, including difficulty-specific targets, remaining target counts, and the normal objective announcements. Enemy health, target deaths, and mission completion are shared with clients rather than relying on each player reaching the same state independently
- Online results use the normal level-end presentation and share mission time, enemy and civilian counts, difficulty, and rewards. Campaign victories apply money, mission and weapon unlocks, Punishment rewards, and ending progression, while failures apply the appropriate penalties and difficulty changes
- Mission exits wait for living players participating in the mission and check that they are still inside before completing. Dead players and players waiting outside the mission do not block the exit, and non-hosts can return to level select or the menu without ending the mission for everyone else
- The CSHQ, Archon Grid, and Trauma Loop ending cutscenes stop on their final shot, cut their music, and show results. The successful Trauma Loop ending offers Next to open the credits, including for the whole Online lobby. Ordinary deaths and competitive results in Trauma Loop do not use this ending flow
- Completing ending credits returns Online players to the main menu. In Singleplayer, letting them finish returns to the Consumer Softproducts opening sequence, or save-slot selection with Skip Intro enabled. Skipping credits with Esc or Enter returns to the main menu



**DIFFICULTY AND SHARED WORLD STATE**



- Added Share Difficulty for the host's Life or Death matrix, Hope Eradicated, Punishment, and Chaos settings. Clients recover their own difficulty state after leaving the session, and mission-entry announcements display the difficulty in use
- Reworked Change Mode on Death to use the shared mission-failure flow instead of applying inconsistent changes between players
- Synchronized time of day, weather, rain, storms, special skies, and relevant world state. Orb interactions are validated through the host so multiple players cannot consume the same orb
- Fixed Death-only atmosphere effects checking the wrong difficulty matrix for clients



**REVIVAL, DEATH, AND SPECTATING**



- Reworked the original revival system with reliable host-to-client and client-to-host interactions, configurable delays, and limited or unlimited revives per player. Self-revival is a separate host option, Counter-Opps restricts teammate revival by team, and Deathmatch disables revival
- Revival restores the player's weapons and normal interactions, including shooting, reloading, and exchanging pickups. Living, dead, loading, and waiting players are tracked separately so departed players do not prevent team wipes or mission completion
- Added configurable spawn invulnerability after entering a mission or being revived. The host can set a duration or disable protection with zero
- Restored Singleplayer's flying-head death camera and dismemberment, with the level continuing to run behind failure results. Permanently dead Online players produce synchronized gibs and blood, while revivable players leave their bodies intact
- Added an option to drop carried weapons on permanent death for other players to collect. Revivable players retain their loadout until their revive allowance is exhausted
- Added third-person spectating, enabled by default through a host setting. The view has no death tint, retracts around walls, supports mouse orbit and scroll-wheel zoom, and uses the strafe controls to switch between living players. Death or disconnection switches to another eligible target, and revival restores the player's own camera. Counter-Opps restricts spectating to teammates unless the host enables opponent spectating



**PLAYER MOVEMENT, APPEARANCE, AND SOUNDS**



- Improved remote movement, aiming, crouching, gravity, sitting, grappling, flashlights, weapons, and death synchronization to reduce snapping, delayed positions, and inconsistent animations. Sideways running and crouching use the corresponding forward movement animations
- Added collision bodies for other players that follow crouching and death state, and synchronized knockback. Player sounds now include more footsteps, jumps, pain, healing, armor, death, and explosions, with equipment-specific footsteps coming from the correct player
- Player names and colors update while connected. Nameplates use the normal compact drop shadow, remain readable independently of body scaling, and disappear beyond twelve world units
- Corrected mirrored outfit textures and lettering on player bodies. Level VI Golem Exosystem users have an animated golem model with Triagon-style material and a taller nameplate position, while Cortical Scaledown+ visibly shrinks player models and collision bodies, including golems



**ENEMIES AND MISSION SYSTEMS**



- Expanded enemy targeting to consider every valid living player instead of only the host. Civilians flee from nearby players, dead players are ignored by targeting, and enemy movement updates are reduced at long distances to avoid unnecessary processing
- Expanded synchronization of enemy and civilian spawns, health, deaths, removals, objectives, and weapon drops. Defeated enemies stay defeated for late joiners, and dead enemies put away their hand-held weapons on client screens
- Synchronized enemy muzzle flashes and directed sight, psychosis, and similar effects at the affected player instead of assuming the host. Added multiplayer handling for special bosses, fleshrats, DNA scrambling, Hope Eradicated and Chaos objectives, and mission-specific interactions
- Synchronized Triagon behavior, targeting, lasers, health, deaths, rewards, and falling heads. DNA scrambler growth and destruction and gunk-related effects are also synchronized, with limits on excessive processing



**COMBAT AND WEAPONS**



- Added a Friendly Fire host setting covering firearms, explosions, fire, radiation, grenades, missiles, vehicles, and thrown objects while retaining self-damage and environmental damage. Improved ownership and kill attribution for attacks with multiple effects
- Expanded multiplayer support for grenades, missiles, the baton, Snoozefest, sedatives, and their status effects. Bolt ACR radiation uses the correct player's ownership and friendly-fire rules, with reduced processing when many radiation effects overlap
- Golem Exosystem punches and the Bolt ACR's direct beam now damage armor. This does not give the Bolt ACR's lingering radiation the same armor-damaging behavior
- Reworked shared weapon pickups, swaps, ammunition transfers, and removal so multiple players cannot collect the same item. Pickup distance, ammunition, and item validity are checked, and bullet casings and impact marks are synchronized
- The Parasonic D2, Minato M9, and Parasonic MP-1 hide the center crosshair while equipped, leaving their laser dots as aiming indicators



**PHYSICS OBJECTS AND LEVEL INTERACTIONS**



- Reworked multiplayer carrying, throwing, and dropping to prevent snapping and conflicting ownership. Held objects are released when their holder disconnects, thrown-object damage credits the responsible player, and physics impacts and radio throws are synchronized
- Expanded synchronization of doors, elevators, switches, difficulty doors, destructible objects, pushblocks, paintings, slot machines, and rotating objects. Elevators retain their positions and play looping movement audio, and inactive or distant physics objects send fewer updates
- Added three passenger seats alongside the driver in cars, with synchronized occupancy, individual entry and exit, and separate passenger cameras. Occupants no longer push the vehicle or retain interaction prompts while seated
- Miner's Miracle's sniper camera affects only the player using it and releases them on death



**STOCK MARKET AND EQUIPMENT PRICES**



- Reworked company stocks around periods of growth, decline, stability, crashes, and recovery instead of fixed price behavior. Existing shares remain saved, and fish and body parts are separate from company-wide market events
- Replaced the original scripted mission changes with Market Outlook events tied to mission completion. Each event happens once per save slot and changes prices gradually over twenty seconds, including the larger booms, collapses, and ending-related events
- Market Outlook describes which companies will rise or fall before completing available missions without revealing exact percentages. The panel shows the most recent mission's exact changes while its market effect is active, then clears them. Secret mission forecasts follow their unlocks, and the CSHQ forecast requires Hope Eradicated and Death mode to have been active together in that save. House has no forecast
- Implant and equipment prices now follow related company stocks within limits that keep them obtainable. Inventory tooltips show the current price and company ticker and update while hovered



**ONLINE EQUIPMENT AND BANS**



- Added Online extension variants with their own inventory sprites and descriptions, keeping their additional multiplayer abilities separate from the original equipment
- Military Camouflage+ dithers the player's body away between nine and twelve units and becomes fully invisible at twelve. Stealth Suit+ uses the optical material associated with shitmen for a partially transparent, dithered appearance. Both effects include glasses and other affected body accessories
- First Aid Kit+ lets the user interact with a nearby player to give them fifty health instead of healing themselves
- Special Sedative Grenade+ slows affected players and gives them a dark, distorted view for ten seconds. The thrower and Level V and VI suits are immune, and the ordinary grenade no longer applies this multiplayer-only effect
- Cursed Torch+ restores health after killing another player, and Augmented Arms+ allows carrying and throwing players as well as normal physics objects, including when used by non-hosts
- Expanded the original implant restrictions into a Bans tab with separate Implants and Weapons lists, presets, Ban All, and Allow All. Changes apply live: banned implants are unequipped without removing ownership, and banned weapons cannot be equipped or picked up. Undiscovered items retain their icons but hide their names and descriptions
- Removed the original unused implant picker from the death screen and its obsolete assets



**NEW IMPLANTS**



- Added Surveillance Eyecam, a PURE implant that scans visible players within fifteen units. After three seconds it displays the target's money, health, Life or Death matrix, implants, and rotating weapon previews beside a tracking rectangle. Losing sight of the player resets the analysis. The display uses typed text, animated expansion and contraction, and a synchronized scan sound
- Added Surveillance Eyecam PRO MAX, experimental remote warfare equipment developed by PURE for Security, Redefined, with pricing tied to SCRD stocks. It acquires the nearest player within ten units and immediately disables one weapon or implant for fifteen seconds. The user's camera and body remain locked toward that player for three seconds even if they move out of range. PRO MAX has a ten-second initial delay and a forty-five-second cooldown, and the victim sees a flashing red hijacking warning naming the affected item. Jammed firearms can still reload
- Added Pneumatic Merit Pump, an arm implant that builds a cash amount exponentially while the tertiary input is held. Releasing throws a cash pickup for another player or NPC, and the user cannot collect their own drop. Overdrawing can put the balance into debt, but the pickup is limited to the money actually owned. Reaching twice the available balance triggers an audible overload and IED-style death without dropping money
- Pump cash can bribe hostile NPCs. Ordinary non-humanoid enemies accept any amount, regular humans require a random payment from $50 to $500, necromechs require $750 to $2,000, and Abraxas and the CSHQ Life boss require $2,500 to $10,000. Human enemies respond with dialogue when paid, either allowing passage or stating the required amount



**VOICE CHAT AND COMMUNICATION**



- Added built-in Steam and LAN voice chat with Push-To-Talk, voice activation, microphone selection, and volume controls. Push-To-Talk defaults to V and supports keyboard or mouse bindings, voice activation stops while typing, and voice volume is independent of the game's master volume
- Voice is positional during missions unless disabled by the host. Underwater speech is muffled, dead players have reverb when heard by living players, and dead players can talk normally to each other. Equipment effects can combine with other voice processing, while menus and results restore normal conversation
- Added speaking indicators, per-player local muting, and host-enforced global muting. A local microphone waveform appears at the bottom-right during Online gameplay, drawing peaks from left to right and changing from green toward red as volume rises
- Composite Helmet slightly muffles the wearer's voice while the helmet is intact
- CSIJ Level V Biosuit heavily muffles the wearer's voice, then adds strong distortion and a short delay
- Speed Enhancer Gland slightly raises voice pitch
- Speed Enhancer Node Cluster raises voice pitch more noticeably
- Speed Enhancer Total Organ Package raises voice pitch substantially
- CSIJ Level VI Golem Exosystem adds a much lower-pitched voice over the normal voice, with a short delay
- Bouncy Suit slightly lowers voice pitch and adds short echoes alternating between the left and right channels, with rapidly changing pitches
- Abominator reverses speech in half-second chunks between upright and inverted players. Two inverted players hear each other normally
- Goo Overdrive makes voice pitch rise and fall in a fast, subtle wave
- Cortical Scaledown+ raises voice pitch
- Hazmat Suit muffles the wearer's voice more than the Composite Helmet
- Holy Scope adds a robotic voice effect
- Stealth Suit+ halves the wearer's proximity voice range
- Reworked the chat window's appearance, text scaling, and dragging. Open Chat defaults to T, opens directly into typing without the pause grid, and blocks player control while keeping the mouse captured. Sending the message or pressing Esc closes it, and opening the pause menu ends this typing view



## GOALS AND MASTERY

- Added an in-game achievement system containing all nineteen original Steam mission achievements alongside new Revitalized goals. The Goals menu shows portraits, requirements, cash rewards, and progress, with All, Campaign, Extras, Mastery, and Online category views
- Added goals for collecting weapons, equipment, fish, and body parts; building a stock portfolio; changing the matrix; defeating the Triagons; removing the Limit Chancellor; eliminating every killable hostile in a mission; and completing the overall achievement collection. These are tracked alongside campaign and mastery progress rather than existing only as Steam notifications
- Added six mastery conditions for each campaign mission: S rank, Hope Eradicated, Punishment, Chaos, Extravagant Suit, and Stripped runs without implants other than the Extravagant Suit. Each mission has its own full-mastery achievement, and additional goals cover completing each condition across the campaign. Progress counts open a mission's mastery page, and existing completed conditions contribute to the campaign-wide goals
- Secret achievements remain visible as mystery entries with hidden names, descriptions, and portraits. Mission secrets are revealed through their progression, special goals use their relevant discoveries or unlocks, and undiscovered mastery conditions remain concealed until known
- Achievement notifications use a rotating phone with the goal portrait and name. Rewards and unlocks apply immediately, while notifications and sounds queue one at a time, with each goal displayed for five seconds. Cash rewards are labeled as deposited
- Goals, mastery, and discovery progress belong to the selected save slot. Existing saves recover applicable achievements from their saved mission records and other tracked progress, and evaluation does not award against an unselected save



## STATISTICS, PROFILES, AND SAVE SLOTS

- Added a Statistics screen with an animated player preview, editable name and name color, and outfit selection by clicking the body. The camera rotates around the preview, its background follows the time of day and special difficulty skies, and body information shows armor, speed, and Life or Death matrix
- Statistics show completion, money, playtime in HH:MM:SS, kills, deaths, goals, and discovered weapons, equipment, fish, and body parts. Collection totals count distinct discoveries, and Online statistics show player kills and total, Deathmatch, or Counter-Opps wins and losses
- Completion can exceed 100%, with base goals contributing up to 100% and mastery contributing another 50% after base completion. The save-slot preview uses the same progress rules as the Statistics screen
- Added four save slots between the opening and main menu, assigning existing save data to Slot 1. Hovering a populated slot shows its progress and character preview, while empty slots have no preview. Skip Intro goes directly to slot selection, where Settings and Quit to OS remain available
- Each slot stores campaign, market, goals, profile, custom-campaign progress, and Online statistics. Selected primary and secondary weapons and all four equipped implants are restored on loading, and the slot preview shows implant icons on the left and weapon icons on the right
- Clearing a save also clears its goals and market progression and returns to save selection. Save-slot Settings excludes destructive progression and timer controls and the credits entry



## MENUS AND PRESENTATION

- Reorganized the main menu into Start, Community, Settings, and Quit, with Online, Goals, and Statistics in level select. Level select starts without a selected mission and keeps the details sidebar hidden until one is chosen. Campaign navigation wraps between available pages and hides its arrows and label when no alternative page exists
- Replaced the two level-select weapon selectors with a Weapons menu using a grid and two side-by-side rotating loadout previews. The selected slot has a green outline, undiscovered weapons use mystery portraits and ??? text, and discovered weapons show their name, description, type, ammunition, damage, weight, and armor-piercing information. Custom weapon pages appear when installed weapons are available
- Equipment and Implants uses Main and Online pages with a single directional switch. Grid reveals, closures, and sidebar transitions run consistently across frame rates, with mission portraits and disabled Start visuals following the same reveal order
- Restyled Online panels, dropdowns, host settings, and tooltips to match the game's menus. The Online pause menu provides Unpause, host Restart Mission, Statistics, Settings with a Return control, and the appropriate exit options. Gameplay input stays blocked while the pause interface or its Settings page is open
- Added V-Sync and automatic saving when settings change. F11 toggles fullscreen from anywhere and updates the saved setting, Return to Save Slots is available from main-menu Settings, and Reset Level Progression has been removed
- Added the Community menu with News and Addons tabs. News supports selectable dated posts, posting times, article text, images, and links to view and reply on Patreon. Current posts demonstrate the layout; Addons remains a placeholder
- Rebuilt credits as a full-screen scroll covering Cruelty Squad, Revitalized, and original CruS Online, with linked creator names, logos, a moving bugs background, and unused Neuron Activator ambient music. The roll ends on the Consumer Softproducts and PurgaTeam logos and a three-second screen effect. Shift increases scroll speed fourfold, and Esc or Enter exits early. Credits are accessible through main-menu Settings and the Trauma Loop ending
- Updated Revitalized branding, version displays, and menu icons, and moved the vertical scrolling Revitalized text to the Online synchronization screen
- Removed the Elsa Holmes outfit
- Results screens hide the level-select sidebar



## CUSTOM MISSIONS, CAMPAIGNS, AND WEAPONS

- Integrated CruS Mod Loader and CruS Mod Base with Online while retaining their custom-mission navigation and menu additions. Custom missions use their portraits, handlers, descriptions, targets, and results through the normal level-select flow
- Added a campaign format with ordered missions, unlock requirements, secret stages, and save-slot-specific progress. The original campaign appears as Cruelty Squad and loose levels as Custom Missions, with next-mission navigation following the selected campaign
- Removed the original bundled multiplayer test maps
- Added self-contained custom weapon packages in the user-data weapons folder alongside levels and campaigns. Definitions can supply models, textures, sounds, ammunition, damage, pickups, and scripted behavior, and weapons can be placed in maps and carried by NPCs. Added a rebindable Shoot Secondary input, defaulting to middle mouse, and API support for alternate attacks. Secondary ammunition has its own rotating HUD icons and inventory statistics
- Online joining checks the host's mods, missions, campaigns, and required content. A confirmation lists names and versions, downloads and verifies missing or outdated content, installs it after closing the game, then restarts and rejoins automatically. Extra client mods can be disabled without deletion, and declined or failed downloads do not enter an incompatible session
- CruS Mod Base's built-in cheats remain available in Singleplayer and are blocked during Online play



## DISCORD RICH PRESENCE

- Added Discord Rich Presence showing Singleplayer or Online state, current mission, difficulty, party size, and mission-specific images. Target counts use the mission's actual remaining objectives, including special difficulty cases, while Deathmatch shows surviving players
- Compatible Steam lobbies support joining through Discord invites and presence, using the normal connection and compatibility checks



## HOST COMMANDS AND DEBUG TOOLS

- Added /kick, session-only /ban, /mute, and /unmute for player moderation; /players for IDs, teams, ping, and living state; and /announce, /restart, /end, /tp, and /help for session management
- Added /op and /deop so hosts can delegate or revoke command access, including debug commands when the host uses a debug build. Administrative revival restores the camera, body, equipment, and control even after a permanent death
- Debug builds include /devhelp and commands for invulnerability, noclip, mission selection, healing, revival, killing, money, weapons, implants, entity spawning, mass NPC removal, and AI freezing. /map list, /give list, and /spawn list show the available catalogs, including installed custom content, and entity spawning supports vehicles and other scene types as well as NPCs
- F2 toggles the interface, difficulty border, crosshair, scope, and target indicators. F3 independently toggles the held weapon and hands. The voice waveform is included in the hidden interface. Both shortcuts work during missions in release and debug builds



## NETWORKING, RELIABILITY, AND PERFORMANCE

- Improved Steam multiplayer networking to reduce synchronization issues and delays. Outdated movement and state updates are discarded or combined, while important events such as deaths and mission transitions are prioritized to prevent delays during heavy combat
- Fixed outdated network information from previous missions interfering with newly loaded levels. Added checks for invalid messages, actions, and interactions, with improved cleanup when players disconnect, entities disappear, or missions change. Leaving a lobby removes its player models and their processing from subsequent Singleplayer missions, and the hidden local multiplayer model does not run remote animation and nameplate updates
- Reduced repeated movement, flashlight, physics, difficulty, and distant-enemy updates, and improved overlapping radiation processing. Steam packet polling stops outside Steam lobbies, and diagnostic object scans run only when debug network logging is enabled. These changes substantially improve multiplayer performance over the original mod, including on lower-end computers
- Added optional traffic, processing, voice, and object diagnostics in debug builds. CRUS_NETWORK_METRICS=1 enables detailed transport logs and CRUS_NETWORK_METRICS=0 disables them; release builds ignore this switch
- Added a Windows crash-report watcher that records recent Godot logs, available Windows crash information, and saved transition and death-handling steps after an unexpected exit. Normal exits do not produce a crash report



## VANILLA GAME FIXES

- Vehicles stop accepting driving input when the driver dies, while remaining controllable during the initial zero-health death countdown
- Removed out-of-bounds handler dialogue triggers outside Pharmakokinetics and Paradise, and removed the unintended elevator interaction from the Paradise pizza-house block
- Made grid-crab movement independent of frame rate. NPC and menu speech now reveals and voices letters on a fixed interval at the original pitch instead of accelerating or skipping letters at higher frame rates
- Corrected startup window-position calculations, including the wrong axis being assigned during resolution changes. Fullscreen toggling also provides a way to restore a misplaced window
- Hope Eradicated music slowdown applies immediately on the title screen and to ambient and combat tracks. Results preserve whichever mission track was playing, and the opening cutscene keeps its original music speed regardless of save difficulty
- The level-entry effect progresses while paused, releases movement when finished, and clears on return to the menu. The opening's scripted shooter and civilians remain active, skipping the live intro restores the final actor, and the save-slot screen stops the cutscene television static without removing it from the opening




