# Anime mirrors on Roku Plus

All anime playback stays inside the existing Roku Plus application and its anime playback flow. These are host adapters, not separate Roku channels.

## Roku playback boundary

Roku's native Video node needs a direct media URL and a supported stream format such as HLS or MP4. It cannot play an arbitrary HTML/JavaScript embed page. The adapter must extract a direct URL, preserve required request headers, and the media itself must use a Roku-supported codec/container.

## Current host adapter status

The current branch adds host discovery and allowlisting for these Latanime mirrors, plus best-effort extraction:

| Host | Current implementation | Confidence |
|---|---|---|
| MixDrop | Unpack common Dean Edwards packed script and read `Core.wurl`; direct HLS/MP4 fallback | Experimental; needs live episode test |
| DoodStream / Dood | `/pass_md5/` token flow and direct MP4/HLS validation against the media-host allowlist | Experimental; CDN hostname may rotate |
| MP4Upload | Direct MP4/HLS URL extraction when exposed by the embed HTML | Partial; pages that require additional JavaScript/API work remain unsupported |
| YourUpload | Direct MP4/HLS URL extraction when exposed by the embed HTML | Partial; dynamic player variants need separate handling |
| Filemoon | Host discovery, allowlisting and generic unpacked/direct URL extraction | Partial; rotating/encrypted key flows are not implemented |
| OK.ru | Host discovery, allowlisting and generic direct URL extraction | Partial; signed API/metadata extraction is not implemented |
| Fembed2 | Host discovery, allowlisting and generic direct URL extraction | Partial; encrypted API/player variants are not implemented |

The Latanime page scan now accepts up to 12 embed candidates, so it can inspect more mirrors from one episode instead of stopping after six.

## Already present in the anime source pipeline

- Latanime episode lookup and embed extraction.
- CineHax, CineCalidad, AllCalidad, LaMovie and SeriesMetro fallback searches.
- The consolidated diagnostic log prefix: `[RokuPlus anime-diagnostic]`.
- Per-embed host diagnostics: `[RokuPlus anime-embed]` and `[RokuPlus anime-host]`.

## Not reliably integrable as a native Roku adapter

These cases cannot be promised as playable merely because a host is discoverable:

- An embed that requires executing arbitrary browser JavaScript, WebAssembly or browser-only APIs.
- A CAPTCHA, Cloudflare/anti-bot challenge, login wall or user interaction that cannot be completed by Roku's HTTP client.
- A host whose stream URL is encrypted with a rotating key and whose public extraction algorithm is unavailable or changes frequently.
- DRM streams when the license flow, key system or provider authorization is unavailable to this app.
- Media using unsupported codecs, containers, audio tracks or malformed HLS manifests.

For those cases the diagnostic should report the exact stage (HTTP block, challenge, missing media URL, unsupported format, or failed stream validation) and continue to the next mirror. It must not pretend the page itself is playable.

## Validation status

The GitHub Actions workflow for this branch packages a ZIP; it does not run the Roku BrightScript compiler or test playback on a physical Roku. Host support remains experimental until the resulting ZIP is installed and each mirror is tested on the target Roku TV.
