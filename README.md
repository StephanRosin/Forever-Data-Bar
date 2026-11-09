# Forever Data Bar

One thin strip across the top or bottom of the screen for WoW: Forever:
experience (with XP per hour, time to the next level and unspent talents),
gold, durability, bags, the clock, up to four professions and four
reputations. Five columns, five designs, your own accent colour. Options
from the gear on the bar or `/fdb`; English, German, Spanish and French.

The full feature list is in [docs/curseforge/description.md](docs/curseforge/description.md).

## Development

    tests/run                    # Lua 5.1, as in the game
    ./install "<WoW>/_forever_/Interface/AddOns"
    tools/package                # dist/ForeverDataBar-<version>.zip
    tools/release release "<changelog>"   # bump ## Version first

Icons: white silhouettes drawn in `tools/art/*.svg`, turned into
`Media/*.tga` (64 px) and tinted in the game.
