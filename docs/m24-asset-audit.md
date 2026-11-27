# M2.4A production asset audit

The audit starts from `develop` at the approved M2.3 merge, `87b68e54db13209636c094745679f54060603c7b`. The post-merge workflow succeeded. The brief records 568 passing checks and scenarios at this baseline. The legacy branch and the dereferenced `v2-legacy` tag point to `7b216583157c960a795da735ecdbb242f13b8b36`. [Post-merge GitHub Actions](https://github.com/dabyong/TUMBANG-PRESO/actions/runs/46003698557)

The review covered the Phase 2 GDD, asset manifest, mobile export instructions, M2.2 and M2.3 design and verification notes, Godot project and scenes, gameplay and UI scripts, mobile staging, and CI. The inventory includes 13 images at repository root and four retired paths recovered from Git history. There are 15 distinct image blobs because three frames share identical bytes. The sheet shows all 17 paths, with a checkerboard for transparency. [Historical contact sheet](m24-visuals/historical-contact-sheet.png)

## Visual inventory

All entries are 1024×1024 PNGs. The scenery is RGB and opaque. The remaining images are RGBA with transparent and partially transparent pixels. Paths are repository-relative. Archived paths are available only in Git history. Short SHAs identify the first observed commit with the inspected blob.

| Path and source commit | Category and intended use | Visual condition and pixel-art fit | Decision and proposed improvement |
| --- | --- | --- | --- |
| `bg-scenery.png` · `866feb7` | Environmental background for the legacy game | Detailed, sunset-lit neighborhood lane. Mixed pixel scale, strong contrast, and location-specific urban features behind text. | Reference the Filipino neighborhood atmosphere. Draw new Batanes scenery with a calmer value range and consistent pixel grid. |
| `hint-frame.png` · `aabdb64` | Woven hint panel | Warm tan material reads at large size. Irregular texture, highlights, and transparent margins compete with hint text. | Reference the palette. Rebuild the hint surface as a responsive panel with restrained texture. |
| `logo.png` · `3ac66b4` | Wordmark and old subtitle | Wide, centered wordmark with extensive transparent padding. Small pixel lettering loses definition at menu scale. | Preserve the title hierarchy as a reference. Draw a tighter new wordmark and render the current subtitle as live text. |
| `reset-button.png` · `aabdb64` | Legacy reset button | Woven button with baked lettering and padded canvas. Single state with uneven texture density. | Rebuild theme states around live labels. Use the current navigation and actions. |
| `scoreboard.png` · `b9b527c` | Score panel | Woven gold frame. Bright border and detailed weave reduce available HUD space. | Rebuild the HUD with live metrics and a compact border. |
| `start-button.png` · `aabdb64` | Legacy start button | Woven button with baked “Start Game” label and padded canvas. Single state. | Use the existing action text and build complete theme states. |
| `tin-can.png` · `aabdb64` | Idle target | Open can with metallic gradient and rust, substantial side padding, and a readable tall silhouette. Fine detail is noisy at HUD scale. | Use silhouette as a reference. Draw a low-resolution can to a shared pivot and footprint. |
| `tin-can-knocked.png` · `aabdb64` | Fallen target | Matching material, wider footprint, and different visual center. Strong highlights break the flatter UI palette. | Redraw the fallen silhouette with the idle can's cell and pivot. |
| `tsinelas-1.png` · `aabdb64` | Answer or projectile variant 1 | Ivory/pink angled flip-flop with a readable outline and low internal contrast. Fine texture disappears at icon size. | Reference the shape. Give the replacement a high-contrast strap and clear sole. |
| `tsinelas-2.png` · `aabdb64` | Answer or projectile variant 2 | Navy and tan provide contrast. Irregular highlights add small-scale noise. | Carry the navy/tan color cue into a simpler stripe pattern. |
| `tsinelas-3.png` · `aabdb64` | Answer or projectile variant 3 | Bright lime/yellow silhouette. Similar-value colors flatten the strap. | Use a distinct strap and a darker outline, checked at answer-row size. |
| `tsinelas-4.png` · `aabdb64` | Answer or projectile variant 4 | Brown sole and variegated strap. Pattern detail disappears first on downscale. | Simplify the strap to two broad bands. |
| `tsinelas-5.png` · `aabdb64` | Answer or projectile variant 5 | Orange/pink outline with a profile close to variant 1. Color carries most of the difference. | Add a distinct tread or strap pattern visible in grayscale. |
| `choices-frame.png` · `aabdb64` · archived | Answer frame | The same blob as the scoreboard and question frame. Wide woven border takes space from wrapping text. | Replace with responsive answer-row surfaces. |
| `question-frame.png` · `aabdb64` · archived | Question panel | The same blob as the scoreboard and choices frame. Bright woven surround competes with long prompts. | Use a calm opaque or nearly opaque reading panel. |
| `starting-frame.png` · `aabdb64` · archived | Title or start splash | Narrow, portrait-style lane illustration with baked lettering and a mix of detail scales. | Draw a landscape menu composition and separate the title and controls. |
| `wrong-answer-counter.png` · `b9b527c` · archived | Miss counter | Tall maroon sandal-themed graphic. Fine details compress in a shallow HUD. | Keep a live miss count. Use a simple icon solely as a supplemental cue. |

## Provenance and disposition

The manifest identifies `bg-scenery.png` and `tsinelas-1.png` as historical AI-generated reference assets requiring review. Embedded background metadata also identifies a composite involving trained algorithmic media. The other current visuals carry Canva creator or export metadata, which records an export signal. Source layers, original authors, element-level licenses, and permissions are unresolved. The retired frames have Git provenance, with the two identical boards sharing the scoreboard blob. Overall commercial-use status is unresolved for all 17 visual paths. Use them as internal references pending source evidence and project-owner approval. [Current asset manifest](asset-manifest.json)

The historical `Sakura-Girl-Yay-chosic.com_.mp3` is third-party music classified as noncommercial in the manifest. The file first appears at `7b21658`, is 6,080,269 bytes, and has SHA-256 `5c6a8748b6189c619028def7fd999578b550e121ebe1f65eb96731d0361da988`. Its release status remains excluded. [Current asset manifest](asset-manifest.json)

Reuse the current live typography, panel layout primitives, and focus and feedback semantics as a foundation. Reuse historical silhouettes, palette ideas, and title hierarchy as design references. Redraw the sprite family, settings and navigation accents, wordmark, and environments as a coherent set. Commission or create original audio after the cue plan is approved.

Open provenance questions include original Canva source projects and element entitlements at export time, creators and modification history, AI provider/model and applicable terms for the two flagged visuals, any identity or location rights needed for new references, and the owner’s recorded approvals. If a source or its terms cannot be established, use newly authored material with a traceable rights record. [Art direction](m24-art-direction.md) · [Production specifications and release policy](m24-asset-specifications.md) · [Audio plan](m24-audio-plan.md)
