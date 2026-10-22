<h1 align="center">D00M — Web Port</h1>

<p align="center">
  <strong>The browser port of <a href="https://github.com/ItCompiledShipIt/D00M">D00M</a>.</strong><br>
  Same game, same procedural everything — compiled to WebAssembly and played in a tab.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-scaffold-orange" alt="Status: scaffold">
  <img src="https://img.shields.io/badge/target-wasm32-blue" alt="Target: wasm32">
  <img src="https://img.shields.io/badge/hosting-Vercel-black?logo=vercel" alt="Hosting: Vercel">
</p>

## What this is

[D00M](https://github.com/ItCompiledShipIt/D00M) is a Doom-style FPS written
from scratch in Rust: hand-written software raycaster, five levels, four
weapons, four monster kinds and a boss, three difficulties, gamepad support —
and zero asset files. Every texture, sprite and sound is generated
procedurally at start-up.

The native game can't run on a web host (it needs a real window, a real
audio device and a permanent process). This repo is the port that makes it
playable in a browser and deployable to Vercel: the game core compiles to
WebAssembly unchanged, and only the platform layer — window, input, audio,
storage — is swapped for web APIs.

**Status: M1 complete.** The v1.0.0 source is imported as the baseline,
and the whole game already compiles and links for
`wasm32-unknown-unknown` with the native test suite green — the platform
swap (M2 onwards) is what remains. The plan, module by module, is in
[PORTING.md](PORTING.md).

## The shape of the port

| Native (D00M) | Web (this repo) |
| --- | --- |
| winit window + event loop | `<canvas>` + `requestAnimationFrame` |
| softbuffer framebuffer | Copy the `&[u32]` frame straight into `ImageData` |
| cpal output stream | WebAudio: buffers from the same synth bank |
| gilrs gamepads | `navigator.getGamepads()` polling |
| Files in `~/.config/d00m/` | `localStorage`, same text formats |

Everything else — `game.rs`, `map.rs`, `levels.rs`, the raycaster in
`render.rs`, the procedural art in `textures.rs`, the synth bank in
`audio.rs`, the 5×7 font, the front-end screens in `ui.rs` — is pure Rust
with no platform calls and ports as-is.

## Build (once the swap lands)

```sh
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
```

The static output (HTML shell + wasm + JS glue) deploys to Vercel as a
plain static site.

## License

MIT — see [LICENSE](LICENSE). Original game:
[ItCompiledShipIt/D00M](https://github.com/ItCompiledShipIt/D00M).
