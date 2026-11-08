# v1.0.0-beta.5 Release Notes

Ship 3D models now render inside a selectable skybox environment with matching lighting. The new model environment is still in preview, so display glitches are expected — reports are welcome.

## Ship 3D Models

- Choose a skybox environment for ship models: automatic by ship race, or manually pick from Universe, Wormholes, Abyssal, and Fitting Bay
- Scene lighting adapts to the selected skybox and ship

## Known Issues

- One face of the skybox renders with no texture; this comes from the underlying Carbon engine and cannot be fixed in the near term
- Skybox textures may look low quality or contain wrong pixels, caused by unknown behavior between the D3D DDS images and the rendering engine
- Skybox lighting is currently too dim while manual lighting tuning is still in progress

The model environment remains in preview. If you run into anything odd, please report it.
