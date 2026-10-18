-- MacShell overrides. SUPER + E opens our Finder, not Dolphin.
fileManager = "~/.config/hypr-macshell/custom/scripts/open-finder.sh"

-- ii's shell binds fall back to fuzzel when `qs -c $qsConfig ipc call TEST_ALIVE` fails. Pointing qsConfig at
-- MacShell makes that probe succeed, so those fallbacks no longer fire a second menu on SUPER + V, SUPER + .,
-- SUPER + SHIFT + S and friends.
hl.env("qsConfig", "MacShell")
