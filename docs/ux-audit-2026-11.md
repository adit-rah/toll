# UX audit, November 2026

QA and design review of every screen on `main` at `3728c45`, as a first-time user would meet it. Sources: the `light` and `ax5` renders of every demo scenario (`render.yml` on `claude/dusk-audit`), their `ui.json` trees, and the views and `Copy` for states the renders can't show (the block screen, the pause sheet's states, the purchase outcomes, errors, empty states, and Off).

Not re-reported: the three Tonight items another branch is fixing (the "8 h 30 m phone-free tonight" line, the bare "TONIGHT" eyebrow, and the inert pill and timeline).

Decided but not built yet, so not audited as missing: D76's lock-before-bed gap, D78's 14-night trial (every "free week" and "7" below becomes 14 nights when #115 lands), D79's sky and D80's Before bed. Where a finding touches one of them, it says so.

**Severity:** P1, a user would misunderstand or get stuck. P2, friction. P3, polish.
**Type:** Vague · Misleading · Dead end · Feedback · Wordy · Inconsistent · Rules · Polish.

## Top 10

_Filled in once every screen is reviewed._

## Tonight

| Issue | Type | Sev | Fix |
|---|---|---|---|
| Away from home at 11:40 pm, the hero shows the night's start, "10:30 pm", in 64 pt under a walking figure, with "Starts when you're home" under it. The biggest thing on screen is a time that has already passed and isn't when anything will happen. | Misleading | P1 | When away inside the night, replace the time with the away glyph tile (as Off does), or show the night's end ("until 7:00 am") with the line "Starts when you're home". |
| While a pause is open, Tonight's hero still reads "Blocked until 7:00 am" with the lock, though every app is open. The pause sheet covers most of it, but the top of Tonight shows behind the sheet. | Misleading | P2 | Give the hero a paused state while `door.phase == .open`: the pause glyph, "Paused until 11:52 pm", no Pause capsule. |
| "You're home · 2 pauses left" repeats what the dots beside it say, and leaves out the period ("left" this week? tonight?). The dots' VoiceOver label says "this week"; the text doesn't. | Vague | P2 | Drop the count from the line ("You're home") and let the dots carry it with "2 of 3 this week" beside them, as the pause sheet does (`Copy.Door.pausesOf`). |
| The morning card's dots are "the last seven nights", labelled by weekday letters ("Mon"), while Your sleep draws the same dots for "this week, Monday to Sunday". Same drawing, two periods; and "Mon" doesn't say whether it is Monday night or Monday morning. | Inconsistent | P2 | Either show this week (Monday-first) on both, or label the morning card's row "Last 7 nights" as an eyebrow. Key each dot by the night's start day and say so once ("nights starting"). |
| "You put it down 3 times" counts "Never mind" taps on the block screen. Someone who tapped "Never mind" and then opened another app still "put it down". "It" has no referent on a screen with no phone drawn. | Misleading | P2 | "You closed a blocked app 3 times", or keep the phrase but draw it with the block screen's own symbol. Same fix on the purchase sheet's stat. |
| The Off state shows the power tile, "Your free week ended.", and then a card "Turn it back on · $9.99 once · every night after". "Every night after" reads as a recurring charge to a quick eye, and "it" isn't named. | Vague | P2 | "Turn Dusk back on" / "$9.99 once, for good". |
| The Off card leads with the moon tile; the state above it uses the power glyph. Two symbols for one thing on one screen. | Inconsistent | P3 | Use `checkmark.seal` (purchased) or the power glyph on the card, not the moon. |
| A tapped Tonight card ("Set home ›", "Turn on") and its "Not now" have no motion row in design §2.5, so the card vanishes in one frame and the hero jumps up. | Polish | P3 | Add a §2.5 row: a dismissed card fades 200 ms and the content below follows with the spring. |
| The tab is "Tonight", but every morning until noon its content is "Last night". | Inconsistent | P3 | Accept, or let the eyebrow carry it: "Last night" in the morning is already right; no tab rename. Note only. |
| Screens pushed from Tonight (Settings) have a back button that reads "Home" (`Copy.Home.backTitle`), the tab's old name; "Home" is also the user's home place. | Inconsistent | P2 | Set the back title to "Tonight" (`Copy.Tabs.tonight`). |
