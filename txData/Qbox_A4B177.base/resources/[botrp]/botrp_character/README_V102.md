# BotRP Character Lobby v1.0.2

Design goals for this pass:
- Keep the GTA world visible with a lightweight, transparent HUD.
- Avoid a large opaque character-list container.
- Keep the 3D preview camera stable while switching characters.
- Keep the game screen faded out until the remote showcase scene is ready.
- Do not restart `NewLoadScene` every frame.

Runtime handoff:
1. `handoff_guard.lua` immediately fades the game out once the network session starts.
2. `client.lua` streams the showcase area and builds the preview ped/camera.
3. The loading screen is not shut down until the preview is ready.
4. The NUI opens and the game fades in only after the camera is active.
5. `showcase_controller.lua` maintains focus/collision without restarting a load scene.
