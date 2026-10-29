# Video toolchain: HyperFrames + Remotion + FFmpeg

Everything needed to create, edit, animate and render videos from code.

| Folder | What it is |
| --- | --- |
| `hyperframes/` | [HyperFrames](https://hyperframes.heygen.com) project (HTML + GSAP compositions → MP4/WebM/MOV/GIF). CLI pinned to `hyperframes@0.8.216`, GSAP vendored in `assets/vendor/` so renders work offline. |
| `remotion/` | [Remotion](https://www.remotion.dev) 4.0.539 project (React compositions → video). Entry: `src/index.ts`, demo composition `Demo`. |
| `scripts/setup.sh` | Installs system packages (FFmpeg, ImageMagick, SoX, MediaInfo, Inter/Noto/emoji fonts), npm deps for both projects, and the headless Chrome builds the renderers use. Idempotent. |
| `scripts/verify.sh` | End-to-end test: renders both demos, then edits them with FFmpeg (crossfade, music bed + loudness normalisation, burned-in captions, HEVC/VP9/ProRes/vertical/GIF exports) and asserts every output with ffprobe. |
| `.claude/skills/` | The HyperFrames agent skills (`hyperframes`, `hyperframes-cli`, `hyperframes-registry`, `media-use`) so Claude Code sessions in this repo know how to author compositions. |

## Quick start

```bash
scripts/setup.sh
```

```bash
scripts/verify.sh
```

Outputs land in `verify-output/` (git-ignored).

### HyperFrames

```bash
cd hyperframes
npm run check                              # lint + runtime + layout + contrast
npx hyperframes@0.8.216 snapshot --at 1,3  # PNG frames to review
npm run render                             # → renders/*.mp4
npx hyperframes@0.8.216 preview --background   # Studio in the browser
```

### Remotion

```bash
cd remotion
npm run dev      # Remotion Studio
npm run render   # → out/remotion-demo.mp4
npm run still    # single PNG frame
```

## Notes for sandboxed / proxied environments

- Headless Chrome may not be able to reach CDNs. Keep scripts, fonts and media local
  (that is why GSAP is vendored) instead of linking `cdn.jsdelivr.net` or Google Fonts at render time.
- Remotion downloads Chrome from `remotion.media`. If that host is blocked,
  `remotion/remotion.config.ts` falls back to `$REMOTION_BROWSER_EXECUTABLE`, then the Chrome Headless
  Shell HyperFrames installed (`~/.cache/hyperframes/...`), then Playwright's (`/opt/pw-browsers`).
- When cross-fading clips from different renderers with FFmpeg `xfade`, normalise them first
  (`fps=30,settb=AVTB,format=yuv420p`): HyperFrames and Remotion write different timebases.
- HyperFrames collects anonymous usage telemetry by default; turn it off with
  `npx hyperframes@0.8.216 telemetry disable`.
- Optional extras reported by `npx hyperframes doctor`: whisper.cpp (transcription), Kokoro (local TTS),
  MusicGen (local music). Not installed by `setup.sh` because they are large; install on demand.
