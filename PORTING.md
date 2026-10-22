# Porting D00M to the web

Baseline: the native game at **v1.0.0** (91 tests), imported unchanged. This document is the work list for turning it into a browser
game deployable to Vercel. Check items off as they land; keep the native
test suite green throughout — it is the spec.

## Why this is feasible

The renderer never touches a graphics API: `render.rs` and `ui.rs` draw
into a plain `&mut [u32]` framebuffer (480×300). The audio bank is
pre-rendered samples, not a live synth graph. The save/config formats are
plain text. All platform contact is concentrated in four files:
`main.rs`, `audio.rs` (stream half), `config.rs` / `save.rs` (file IO),
`pad.rs`.

## Ports as-is (no changes expected)

- `math.rs` — Vec2, RNG, noise
- `levels.rs` — the five ASCII maps
- `map.rs` — grid, doors/secrets, collision, line of sight
- `game.rs` — player, weapons, enemy AI, pickups, explosions, difficulty
- `render.rs` — raycaster, sprites, HUD, automap (writes `&[u32]`)
- `textures.rs`, `gfx.rs`, `font.rs` — procedural art and the 5×7 font
- `ui.rs` — title/intro/settings/volume/pause/intermission screens
- `audio.rs` (bank half) — every synthesised effect, the ambient loop and
  the score, rendered at start-up exactly as native

## Needs a web replacement

### `main.rs` — window, loop, input
- Replace the winit event loop with a `requestAnimationFrame` loop
  (wasm-bindgen + web-sys). Feed the same `Input` struct the native loop
  builds, from DOM keyboard/mouse listeners.
- Blit: copy the framebuffer into a `Uint8ClampedArray` `ImageData` and
  `putImageData` to a 2D canvas, CSS-scaled up. Pixel format is the one
  real gotcha: the framebuffer is `0x00RRGGBB` u32s; ImageData is RGBA
  bytes — convert per pixel in the blit (cheap at 480×300) and set alpha
  to 255.
- Mouse look: Pointer Lock API on canvas click.
- Fullscreen setting: `Element::requestFullscreen`.

### `audio.rs` — output only
- Keep `Bank::generate` untouched: it produces the same `Arc<Vec<f32>>`
  samples.
- One-shots: wrap each effect in an `AudioBuffer` once; play via
  `AudioBufferSourceNode` → `StereoPannerNode` (gain/pan are already
  computed per request) → `GainNode` → destination.
- Ambient + music: two looping `AudioBufferSourceNode`s with the same
  gain staging and crossfade the native mixer does (ambient volume,
  duck, music mix). The native mixer's per-sample crossfade math is the
  reference; WebAudio `setTargetAtTime` ramps are the web equivalent.
- Browsers require a user gesture before audio starts: initialise the
  `AudioContext` on the first click/keypress (the title screen's first
  Enter is a natural point).

### `config.rs` / `save.rs` — storage
- Replace `std::fs` reads/writes with `localStorage` get/set under the
  same keys (`config`, `save1`–`save3`, `scores`). The text formats
  (`D00M SAVE 1`, the config lines) stay byte-identical, so a save string
  can be moved between native and web by copy-paste.
- The decode paths are already defensive (corrupt data is skipped, never
  half-loaded) — keep that behaviour for truncated localStorage values.

### `pad.rs` — gamepad
- Replace gilrs with `navigator.getGamepads()` polling once per frame,
  mapped onto the same `PadAction` set. Same deadzones, same mapping
  table where the buttons line up (standard mapping).

### `shot.rs` — headless capture
- Native-only tooling. Gate it `#[cfg(not(target_arch = "wasm32"))]`;
  the browser equivalent is "right-click → save canvas", which needs no
  code.

## Build and deploy

- Target: `wasm32-unknown-unknown`. Glue: `wasm-bindgen` (hand-written
  `index.html` shell, no bundler — keeps the zero-build-tool spirit).
- `Cargo.toml`: verified at M1 — all four native dependencies (`winit`,
  `softbuffer`, `cpal`, `gilrs`) compile **and link** for wasm32
  unmodified; each ships a web backend, so no target-gating was needed
  just to build. Whether those backends are the right runtime path (vs.
  the hand-rolled canvas/WebAudio plan above) is an M2 decision. A
  native build of this repo must still pass `cargo test` — that is the
  regression net.
- Output is three static files → deploy to Vercel as a static site, no
  framework, no server functions.

## Milestones

- [x] M1 — `cargo build --target wasm32-unknown-unknown` compiles; native
      `cargo test` still green (done 2026-10-22: zero code changes needed
      for the build itself; three pre-existing clippy lints fixed along
      the way, so both targets are now warning-free. One fix removed a
      duplicated `#[test]` attribute that had been running the secrets
      test twice — the suite is 91 unique tests, not 92)
- [x] M2 — Canvas blit live: title screen renders and animates in a tab
      (done 2026-10-22, screenshot-verified in headless Chromium. The
      winit/softbuffer web backends do the blit themselves — no
      hand-rolled ImageData path needed. Entry is a wasm-bindgen start
      function calling `EventLoop::spawn_app`; the window binds to the
      page's `#d00m-canvas`. One real porting fix: `std::time::Instant`
      panics on wasm32, so frame timing uses the `web_time` crate, which
      is `std::time` on native)
      Addendum (same day): the localhost verification masked a crash that
      hit every real device — the native 60 fps frame cap *sleeps the
      thread*, which panics on wasm; localhost's virtual-time clock
      always showed a full frame elapsed, a real browser's does not.
      The sleep is native-only now (rAF paces web frames), and the cpal
      and gilrs web backends are gated off in favour of stubs — WebAudio
      (M4) and the Gamepad API (M6) will be deliberate implementations,
      not backend luck. Re-verified over the LAN origin that failed:
      title renders, console panic-free)
- [ ] M3 — Input wired: playable through E1M1 with keyboard + mouse
- [x] M4 — Audio: effects, ambience and score through WebAudio (done
      2026-10-22, ahead of M3 at the owner's steer. Not a node-graph
      rewrite: a ScriptProcessorNode callback feeds the *same* Mixer the
      native cpal callback feeds — identical voices, beds, ducking and
      crossfades. The context starts suspended under the autoplay policy
      and resumes on the first click/keypress. Verified headlessly via
      the exported `d00m_audio_info()` diagnostic: context running at
      48 kHz, rendered blocks non-silent. Note the title screen itself
      is silent by design on every platform — the menu duck is 0; the
      drone fades up in pause/intermission/gameplay)
- [ ] M5 — Settings, saves and scores persist in localStorage
- [ ] M6 — Gamepad via the Gamepad API; deployed to Vercel

## Non-goals

- No engine, no framework, no bundler, no asset pipeline. The native
  game's rules travel with it: everything procedural, everything from
  source.
- No changes to gameplay, balance or content. If the web build plays
  differently from native v1.0.0, that is a port bug.
