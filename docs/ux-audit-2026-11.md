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

## Block screen (system shield, `ShieldText`; from the code, the simulator can't show it)

| Issue | Type | Sev | Fix |
|---|---|---|---|
| "Pause in Dusk" doesn't say what happens: it opens Dusk, where a 60-second wait starts only after a second tap. Read quickly it can mean "pause, inside Dusk" or "Dusk is paused". | Vague | P2 | "Open Dusk to pause" (or "Pause… in Dusk", with the ellipsis meaning "more to choose"). |
| The night's title is "Blocked until 7:00 am"; another block's is "Study · until 5:00 pm". Two patterns for the same fact on the same screen. | Inconsistent | P3 | One pattern: "Blocked until 5:00 pm" for both, with the block's name in the subtitle ("This app is blocked during Study."). |
| A website gets "This app is blocked for the night." | Misleading | P3 | Pass whether the shield is for a web domain into `ShieldText` and say "This site is blocked for the night." |
| With none left the subtitle runs "This app is blocked for the night. No pauses left · back Monday": a middle dot and no full stop inside prose. | Polish | P3 | "No pauses left. They come back Monday." |
| "Never mind" closes the app, but the label doesn't say so, and it's counted as "you put it down" elsewhere. | Vague | P3 | Keep "Never mind" (D32), but the Tonight and purchase stats should describe it as closing the app (see Tonight). |

## Pause sheet (`DoorSheet`; `door-*` renders and the code)

| Issue | Type | Sev | Fix |
|---|---|---|---|
| While waiting or paused the sheet can't be dismissed (`interactiveDismissDisabled`) and has no close button. For 11 minutes, Your sleep, Blocks and Settings are unreachable inside Dusk; "You can leave this screen" only means leaving the app. | Dead end | P2 | Allow a swipe down while waiting and while open (the wait and the pause run on the monitor anyway), and keep a small status on Tonight that reopens the sheet. Or a "Hide" quiet button. |
| Waiting stacks three lines of reassurance: "Every app opens for 10 minutes when the wait ends.", "You can leave this screen. The wait keeps going.", and "Cancelling costs nothing." under Cancel. The choosing state already said cancelling costs nothing. | Wordy | P3 | Keep the countdown, the bar and one line ("Opens for 10 minutes when this ends."); drop "Cancelling costs nothing." under Cancel. |
| "Every app opens" reads as "every app on the phone launches". Only blocked apps were closed. | Vague | P3 | "Blocked apps open for 10 minutes." |
| After the 2-minute regret window, "Lock again" looks the same but now spends the pause. Nothing says so once the regret line fades. | Feedback | P2 | Once the regret window ends, show a quiet line over the button: "The pause is used. Locking ends it early." |
| After "Lock again" the sheet closes with no word; whether the pause came back shows only as a dot refilling on Tonight under the closing sheet. | Feedback | P3 | Keep the sheet up 1 s with the dot refilling (the §2.5 pip crossfade), or a `.success`-free `.light` haptic as the dot fills. Needs a §2.5 row if motion. |
| None left draws seven segments for "the week so far". The same segments mean the free week on Welcome, Ready, the pill and the purchase sheet, and the limits on Blocks. Three meanings, one drawing. | Inconsistent | P2 | Draw the week as the night dots (`NightDots`, the week's own drawing), or drop it: "back Monday" already says when. |
| None left is mostly unreachable: Tonight hides the Pause capsule at 0 and the block screen drops "Pause in Dusk" at 0 (D70). | Polish | P3 | Fine as a guard; no change, but don't spend more design on it. |
| The Pause capsule on Tonight and the "Pause for 10 min" button use `pause`; the Open state uses `pause` before "Paused"; good. But the choosing title asks "Pause blocking for 10 minutes?", and Blocks' footnote says "A pause opens every block at once." Three phrasings of one rule. | Inconsistent | P3 | One sentence everywhere: "A pause opens every blocked app for 10 minutes." |

## Purchase sheet (`purchase` render and the code for its outcomes)

| Issue | Type | Sev | Fix |
|---|---|---|---|
| Early in the week the stats read "0 nights phone-free", "0 times you put it down", "0 pauses used". A row of zeros is a shortfall in all but name (D65), and it's the selling moment. | Rules | P2 | Hide a stat at 0, and hide the card until a night has ended; the segments already say how far in the week is. |
| "Pauses used" on a sheet that asks for money reads as a tally of slips. | Rules | P3 | Drop it; nights and the times put down are the two facts about the person. |
| "Times you put it down" (see Tonight) counts "Never mind" taps. | Misleading | P2 | As on Tonight. |
| Between "Keep it" and Apple's payment sheet the button only greys out; nothing says work is under way. Same for "Restore purchase". | Feedback | P3 | A `ProgressView` inside the disabled button while `working`. |
| "The purchase didn't go through": "Check your payment details in Settings › Apple Account" with no way there. | Dead end | P3 | Fine to leave (App Store review prefers no deep link); at most a "Not now" that keeps the sheet. Note only. |
| The done state, "Every night is yours", is a title, the seven full segments and "Done", and nothing about what changes now. | Vague | P3 | One line under it: "Dusk keeps blocking every night. Nothing else to do." |
| The segments' VoiceOver label is "Your free week" with no count. | Rules (AX) | P3 | "Night 3 of 7 free" (`Copy.Home.nightPill`). |
| D78 makes the trial 14 nights: the eyebrow "Your free week", the pill, Welcome's "7 nights free" and "Start my free week", Ready's footnote and seven segments all change. Fourteen segments won't fit Welcome's card at AX5 as drawn. | Polish | P3 | Plan with #115: "Free nights" instead of "free week", two rows of seven segments. |

## Settings (`settings`, `settings-anywhere`, `settings-heads-up-denied`)

| Issue | Type | Sev | Fix |
|---|---|---|---|
| "Only when I'm home · On" opens the map again; nothing in Settings turns it off. The only way back to "anywhere" is Blocks › Your nights › Place › Use anywhere, a different flow with a different picker. | Dead end | P2 | Make the row a switch-like row: on opens the map; when on, its sheet offers "Use anywhere" under the map. |
| The Location row ("While Using", "Off") is inert, though the screen's question is "Is everything working?" and While Using means home doesn't work. Screen Time's row offers "Turn on" when off; location offers nothing. | Dead end | P2 | When home is set and location isn't Always, make the row a `SettingsLink` to iOS Settings (with `arrow.up.forward.app`). |
| "Last blocked · 10:30 pm – 7:00 am" has no day, and can be a Study block at 5 pm. | Vague | P2 | "Last night · Mon 10:30 pm – 7:00 am", from the night log only (`NightFacts`), or the day name when it isn't last night. |
| "Restore purchase" has a chevron, which promises a screen; it's an action. On success nothing is said: the row above changes to "Purchased" and `Copy.Settings.restored` ("Purchase restored.") is never shown. It stays on screen after purchase. | Feedback | P2 | No chevron; a short-lived "Purchase restored." detail on the row; hide the row once purchased. |
| A "Blocks" row in Settings pushes a second copy of the Blocks tab. Two ways to the same screen, with different back buttons. | Inconsistent | P3 | Remove the row; Blocks is a tab. |
| "Privacy" has a chevron but, when `TollPrivacyURL` is empty, isn't tappable. "Contact" is a link with no chevron. | Inconsistent | P3 | Hide Privacy when there's no URL; give every outbound link `arrow.up.forward.app` (they leave the app). |
| "How it works" is a sheet with no button: swipe-down only. At AX5 it's full height. | Dead end | P3 | A "Done" button in its actions. |
| The version is shown only inside "Activity log", which is "removed before launch". After launch there's no version anywhere for support. | Polish | P3 | A quiet version footnote at the bottom of Settings. |
| Settings is reachable only from Tonight's gear; from Your sleep and Blocks there's no way to it. | Polish | P3 | Accept (D63), or put the gear on all three tabs. |

## Your sleep (`insights`, `sleep-monday`, `sleep-best`)

| Issue | Type | Sev | Fix |
|---|---|---|---|
| The first card is "23 nights" beside a moon, with no word for what a night is: nights of sleep? nights tracked? nights since install? | Vague | P1 | "23 nights phone-free" (`Copy.Home.nightsLabel`, already in `Copy`) as the card's detail, or "23 nights with apps locked". |
| "214 h phone-free" adds up every block's hours, Study and Gym included (`InsightsSnapshot.hoursBlocked` reads every `blockOn` line), on a tab called Your sleep, next to a chart of the night. It's also not "phone-free": everything not on the list stayed open. | Misleading | P1 | Count the night's block only, and say what it is: "61 h with apps locked at night". Same family as the founder's "phone-free tonight" flag. |
| "30 days" and "All time" read the transition log, which keeps 2,000 lines (about ten nights by `YourSleep`'s own comment). After a few weeks "All time" shows less than the "23 nights" card above it. | Misleading | P1 | Build the range stats from the night log (`nights.jsonl`, D62), which never trims, or drop "All time" until they do. |
| The range picker sits under the week cards but only changes the stat and the chart below it. It looks like it scopes the whole tab. | Vague | P2 | Put the picker under a section header ("Over time") or replace it with one fixed range ("Last 30 nights"). |
| "When you put it down" is a bar chart of "Never mind" taps by hour, 10 pm to 6 am, whatever the person's night is. Its title doesn't say what's counted, and a 12:30 – 8:30 am night loses its last two hours. | Vague | P2 | Title "When you closed a blocked app"; fit the hours to the night's own span (as D60 did for the strip). |
| The chart is hidden from VoiceOver; only "Most at 11 pm" is read. | Rules (AX) | P2 | An `accessibilityLabel` that reads the peak and the total, or an Audio Graph (`accessibilityChartDescriptor`). |
| `InsightsView` labels its picker "Your nights" (`Copy.Insights.title`), the night editor's title, on the tab "Your sleep". | Inconsistent | P3 | Label it by what it picks: "Range". |
| The tab is named Your sleep and shows no sleep: everything here is about the lock. Until Health lands (#86) the name promises more than it gives. | Misleading | P3 | Note for product; no change before #86 (D63, D65). |
| "A new week" shows seven empty dashed dots on Monday morning. | Polish | P3 | Fine (D69); the line "N nights last week" carries it. When last week had no nights, the card is only dashed rings: add nothing, but check it with the renders. |
