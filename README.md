# Forever Data Bar

One thin strip (or up to four) across the top or bottom of the screen for WoW: Forever:
experience (with XP per hour, time to the next level and unspent talents),
gold, durability, bags, the clock, up to four professions and four
reputations, and other addons' LibDataBroker feeds. Five columns, five designs, eight themes (beta), your own
accent colour. Options from the gear on the bar or `/fdb`; English, German, Spanish and French.

The full feature list is in [docs/curseforge/description.md](docs/curseforge/description.md).

## Development

    tests/run                    # Lua 5.1, as in the game
    ./install "<WoW>/_forever_/Interface/AddOns"
    tools/package                # dist/ForeverDataBar-<version>.zip
    tools/release release "<changelog>"   # bump ## Version first

Icons: white silhouettes drawn in `tools/art/*.svg`, turned into
`Media/*.tga` (64 px) and tinted in the game.

The themes (textures, fonts, colours) come from the embedded library LibForeverThemes in
`Libs/LibForeverThemes` (source: https://github.com/StephanRosin/ForeverThemes, copied in with
its `tools/sync`). Its fonts in `Media/Fonts` are under the SIL Open Font License (see `OFL.txt`
and `FONTS.txt` there).
