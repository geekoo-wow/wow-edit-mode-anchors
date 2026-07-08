# Edit Mode Anchors

## **Take total control over your UI layout with pixel-perfect precision.**

While World of Warcraft’s native Edit Mode revolutionized UI customization, it often leaves power users wanting more. **Edit Mode Anchors** is a lightweight extension designed to bridge the gap between "roughly placed" and "perfectly aligned."

No more dragging frames by hand and hoping they line up—this addon introduces a dedicated control suite to the existing Edit Mode interface, allowing you to manipulate every frame with mathematical exactness.

## Key Features

*   **Precise Offset Controls:** Fine-tune your X/Y coordinates using input boxes or increment buttons. Move frames 1 pixel at a time for that flawless look.
*   **Advanced Anchor Management:** Choose specific attachment points (e.g., Top-Left to Bottom-Right) to create complex layouts that stay put.
*   **Native Integration:** Designed to feel like a part of the game. The tools appear directly within the standard Edit Mode selection flyouts.

## Known Issues

### "EditModeAnchors has been blocked from an action only available to the Blizzard UI" when sharing a layout

Edit Mode's **Share → Copy to Clipboard** feature uses `CopyToClipboard()`, a protected function that only Blizzard's untainted ("secure") code is allowed to call. This addon works by writing custom anchor values directly into the Edit Mode layout data, and WoW's security model marks any data written by an addon as *tainted*. Once the share feature reads that tainted layout data to serialize it, the whole operation is considered tainted and the protected clipboard call gets blocked — with the dialog blaming this addon.

This is inherent to how the addon works and cannot be avoided from addon code (taint is one-way; there is no way to "clean" the data once written). The layout data itself is fine: it saves and exports correctly.

**Workaround:** the in-memory layout data is only tainted for the current session, and only after you've changed a setting through this addon. To share a layout:

1. Save your changes.
2. Fully exit Edit Mode (or `/reload`) — re-entering Edit Mode reloads the layout data cleanly.
3. Use Share → Copy to Clipboard *before* touching any Anchor Override setting.

The export will then work normally and includes all your custom anchors.

## Disclaimer

This addon is a product of pure vibe coding; while it has been tested primarily on Retail and seems to be holding it together, I offer no guarantees that it’s actually "good" or even reliable. Consider this an experimental labor of love rather than a polished professional tool. Use it at your own risk, keep your expectations low, and enjoy the vibes.
