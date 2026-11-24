# UX audit, November 2026

QA and design review of every screen on `main` at `3728c45`, as a first-time user would meet it. Sources: the `light` and `ax5` renders of all 53 demo scenarios (`render.yml` on `claude/dusk-audit`, published to `renders/claude/dusk-audit`), their `ui.json` trees, and the views and `Copy` for what the renders can't show (the block screen, the pause sheet's other states, the purchase outcomes, errors, empty states, and Off).

Not re-reported: the three Tonight items another branch is fixing (the "8 h 30 m phone-free tonight" line, the bare "TONIGHT" eyebrow, and the inert pill and timeline).

Decided but not built yet, so not reported as missing: D76's lock before bed, D78's 14-night trial (every "free week" and "7" below becomes 14 nights with #115), D79's sky and D80's Before bed. Where a finding touches one of them, it says so.

**Severity:** P1, a user would misunderstand or get stuck. P2, friction. P3, polish.
**Type:** Vague · Misleading · Dead end · Feedback · Wordy · Inconsistent · Rules (D65/D74, wordless test, AX5) · Polish.

## Top 10

1. **P1 · Your sleep's "phone-free" hours count every block.** "214 h phone-free" adds Study and Gym hours to the night's, on the tab called Your sleep. ([Your sleep](#your-sleep))
2. **P1 · Your sleep's "30 days" and "All time" read a log that keeps about ten nights.** `sleep-best` shows "20 nights" at the top and "51 h phone-free" over 30 days below it. ([Your sleep](#your-sleep))
3. **P1 · Away from home, Tonight's biggest element is a time that has passed.** At 11:40 pm it shows "10:30 pm" over "Starts when you're home". ([Tonight](#tonight))
4. **P1 · "23 nights" on Your sleep has no noun.** Nights of what: sleep, tracking, use? ([Your sleep](#your-sleep))
5. **P2 · At AX5 every sheet's main action scrolls off screen.** "Lock again" sits below the fold during its 2-minute window, "Pause for 10 min" too, and the purchase sheet's price and "Keep it" are three pages down. Design §2.1 says the main button stays pinned. ([All screens](#all-screens))
6. **P2 · The pause sheet holds the app for 11 minutes.** While waiting and paused it can't be dismissed and has no close button, but still shows a grabber. Your sleep, Blocks and Settings are out of reach. ([Pause sheet](#pause-sheet))
7. **P2 · During a pause, Tonight still says "Blocked until 7:00 am"** with the lock, behind the sheet that says "Paused". ([Tonight](#tonight))
8. **P2 · Mornings show two nights with no labels.** The card is last night. The strip under it is tonight, from "8 am" to "8 am". The dots are sometimes the last seven nights and sometimes include nights to come. "Mon" can mean Monday night or Monday morning. ([Tonight](#tonight))
9. **P2 · "You put it down" counts "Never mind" taps.** The phrase is on Tonight, the purchase sheet and Your sleep's chart. Closing a blocked app isn't putting the phone down, and "it" has no referent. ([Tonight](#tonight))
10. **P2 · Home can be set from two places, with two different pickers, and neither turns it off.** "Only when I'm home · On" in Settings reopens the map. The night editor's Place row uses the generic Building / Street / Campus picker. ([Settings](#settings))

**Count:** 4 P1 · 32 P2 · 50 P3 (86 issues).

## All screens

| Issue | Type | Sev | Fix |
|---|---|---|---|
| At AX5 `SheetPage` scrolls its actions with the content instead of pinning them. ax5 `door-open`: "Lock again" at y 879 on an 874 pt screen. `door-choosing`: "Pause for 10 min" at 900. `door-none`: "OK" at 904. `purchase`: "Keep it" at 1414, three pages down. | Rules (AX5) | P2 | Pin `actions` under the `ScrollView` in `SheetPage`, as `tollBottomBar` does on screens. |
| Glyphs are fixed point sizes (`.font(.system(size: 13))`) beside text that scales to AX5. At AX5 the house, lock, clock, moon and sun are specks beside 40 pt words. ax5 `home-blocked`, `blocks` and `ready` show it. | Rules (AX5) | P3 | Scale glyphs with their line, using `@ScaledMetric` or a text-style font with `imageScale`. |
| Seven segments mean three things: the free week (Welcome, Ready, the pill, purchase), the week so far (pause, none left) and "Sets of hours" (Blocks). | Inconsistent | P2 | Keep segments for the free nights only. Draw the week as `NightDots`, and the sets of hours as a `CapacityBar` like apps. |
| Image names leak to VoiceOver inside some combined elements, including `iphone.slash`, `arrow.up.forward.app` and `scope`, as raw strings in `ui.json`. | Rules (AX) | P3 | `accessibilityHidden(true)` on every decorative `Image(symbol:)`. Several already have it. |

## Tonight

| Issue | Type | Sev | Fix |
|---|---|---|---|
| Away inside the night (`home-away`, 11:40 pm), the hero shows the night's start, "10:30 pm", at 64 pt with "Starts when you're home" under it. The biggest thing on screen has already passed and isn't when anything will happen. The walking figure is drawn twice: in the pill and before the eyebrow. | Misleading | P1 | When away inside the night, show the away glyph in the 64 pt tile, as Off does, with "Starts when you're home". Drop the pill's copy of it. |
| While a pause is open, the hero still reads "Blocked until 7:00 am" with the lock, though every app is open. It shows above the "Paused" sheet (`door-open`). | Misleading | P2 | Give the hero a paused state while `door.phase == .open`: the pause glyph, "Paused until 11:52 pm", and no capsule. |
| Mornings (`home-morning`, `home-day`): the card is last night, and the strip under it is tonight, with no label and hour marks "8 am · 2 pm · 8 pm · 2 am · 8 am" that start and end on the same words. Tonight's start isn't written anywhere until noon. | Vague | P2 | Put "Tonight 10:30 pm" over the strip in the mornings, or hide the strip while the morning card shows. |
| The card's seven dots change period. At 8:10 am they are the last seven nights (Tue to Mon). At 11 am (`home-day`) they run Thu to Wed, with Tue and Wed "still to come". Your sleep draws the same dots for Monday to Sunday. Each dot is labelled with the day the night starts, so on Tuesday morning last night reads "Mon". | Inconsistent | P2 | Always show the last seven ended nights here, with a small "Last 7 nights" eyebrow. Keep Monday to Sunday for Your sleep. |
| "You put it down 3 times" counts "Never mind" taps on the block screen. Someone who closes one blocked app and opens another has still "put it down". "It" has no referent. | Misleading | P2 | "You closed a blocked app 3 times". Same wording on the purchase sheet and Your sleep's chart. |
| Off (`home-paused`): the 64 pt power tile looks like a power button, and tapping it does nothing. The card under it reads "Turn it back on · $9.99 once · every night after". "Every night after" can read as a recurring charge, and "it" isn't named. The card's tile is a moon, while the state is the power glyph. | Misleading | P2 | Make the card the only action: "Turn Dusk back on · $9.99 once, for good", with the power glyph. Give the tile no button shape, or make it open the sheet as well. |
| Screen Time off (`home-screen-time-off`) says it twice: a warning card with "Turn on", then a warning tile shaped like a button with "Turn it on to block tonight." | Wordy | P3 | Keep the card. Under the tile, say only what's true tonight: "Nothing blocks tonight". |
| No night (`home-no-blocks`): "Nothing scheduled", 40 pt, with nothing to do. There's no link to set the night, and the pill still counts "Night 1 of 7 free". | Dead end | P2 | Add a main button, "Set your night", that opens the night editor. Hide the pill while there's no night. |
| At AX5 a Tonight card (`home-card`) fills the screen. The state, the one thing Tonight answers, is pushed under the tab bar. | Rules (AX5) | P2 | At accessibility sizes, put the hero first and the card after it. |
| "You're home · 2 pauses left" repeats the dots beside it, and doesn't say over what period. The dots' VoiceOver label says "this week"; the text doesn't. | Vague | P2 | "You're home" alone, with "2 of 3 this week" beside the dots as on the pause sheet (`Copy.Door.pausesOf`). |
| Screens pushed from Tonight have a back button that reads "Home" (`ui.json`: `Button 'Home'`), the tab's old name. "Home" is also the user's place. | Inconsistent | P2 | Set the back title to "Tonight" (`Copy.Tabs.tonight`). |
| Without Always (`home-location`), the hero line "Starts at 10:30 pm, wherever you are" repeats the big time above it. | Wordy | P3 | "Wherever you are", with the globe. |
| The pill's segments fill for nights that have ended, so "Night 5 of 7" shows four filled. Read quickly, the count and the drawing disagree. | Vague | P3 | Draw tonight's segment as an accent outline. |
| The gap in last night's bar (`home-morning-gap`) has no mark. A first-time user may read it as a glitch. | Vague | P3 | A small pause glyph over the gap, with the same `.micro` size as the times. |
| The "Pause" capsule's VoiceOver label is "Pause", with no object. | Rules (AX) | P3 | Label it "Pause blocking". Keep "Pause" as the visible word. |
| Tapping "Not now" or an action on a Tonight card removes it in one frame, and the hero jumps up. Design §2.5 has no row for it. | Polish | P3 | Add a §2.5 row: the card fades over 200 ms and the content below follows with the spring. |
| After "Turn on" on the heads-up card, iOS asks, then the card vanishes. Nothing says it's on. | Feedback | P3 | Change the card to "Heads-up on · 10:10 pm" for the rest of the evening. |

## Block screen

Read from the code (`ShieldText`, `ShieldConfigurationExtension`): the simulator can't show the system shield.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| "Pause in Dusk" opens Dusk, where the person still has to tap to start a 60-second wait. Read quickly, it can mean "pause, inside Dusk" or "Dusk is paused". | Vague | P2 | "Open Dusk to pause". |
| The night's title is "Blocked until 7:00 am"; another block's is "Study · until 5:00 pm". Two patterns for one fact. | Inconsistent | P3 | "Blocked until 5:00 pm" for both, with the block named in the subtitle ("This app is blocked during Study."). |
| A website gets "This app is blocked for the night." | Misleading | P3 | Pass whether the shield is for a web domain into `ShieldText` and say "This site…". |
| With none left: "This app is blocked for the night. No pauses left · back Monday". A middle dot and a missing full stop inside prose. | Polish | P3 | "No pauses left. They come back Monday." |

## Pause sheet

`door-choosing`, `door-waiting`, `door-open` and `door-none`, plus the code.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| While waiting or open the sheet can't be dismissed (`interactiveDismissDisabled`) and has no close button, but shows a grabber. For up to 11 minutes, Your sleep, Blocks and Settings can't be reached. "You can leave this screen" means only leaving the app. | Dead end | P2 | Allow swiping it down; the wait and the pause run on the monitor anyway. Tonight's paused hero (see Tonight) reopens it. |
| After the 2-minute regret window, "Lock again" looks the same but now ends a pause that's already spent. Nothing says so once the regret note fades. | Feedback | P2 | After the window, a quiet line over the button: "This pause is used. Locking ends it early." |
| Open shows two countdowns at once ("9:02 left" and "in the next 1:02"), plus a tick on the bar. | Wordy | P3 | Keep the big countdown and the tick. Make the note "Lock again before the tick and you keep the pause." |
| Waiting stacks three reassurances: "Every app opens for 10 minutes when the wait ends.", "You can leave this screen. The wait keeps going." and "Cancelling costs nothing." under Cancel. The choosing state has already said cancelling costs nothing. | Wordy | P3 | Keep one line, "Apps open for 10 minutes when this ends.", and drop the footnote under Cancel. |
| "Every app opens" can be read as every app on the phone launching. Only blocked apps were closed. | Vague | P3 | "Blocked apps open for 10 minutes." Same on Ready and in How it works. |
| Choosing says "2 of 3 left this week" next to a drawing of one filled dot and one dashed dot, the state after this pause. The words and the picture count different moments. | Inconsistent | P3 | "This uses 1 of 2 left". |
| After "Lock again" the sheet closes with no word. A refilled dot on Tonight is the only sign the pause came back. | Feedback | P3 | A `.light` haptic as the dot fills. Design §2.5 already has the pip crossfade. |
| None left draws the week as seven segments, with no label and the current night filled. | Inconsistent | P3 | Drop it; "back Monday" says when. See All screens on segments. |
| One rule, three phrasings: "Pause blocking for 10 minutes?", "A pause opens every block at once." on Blocks, and "Pause opens every app for 10 minutes after a one-minute wait." in How it works. | Inconsistent | P3 | One sentence everywhere: "A pause opens blocked apps for 10 minutes." |

## Purchase sheet

`purchase`, `purchase-done`, `-failed`, `-pending` and `-restore-none`.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| Early in the trial the stats read "0 nights phone-free", "0 times you put it down" and "0 pauses used". A row of zeros is a shortfall in all but name (D65), shown at the moment of asking for money. | Rules | P2 | Hide any stat at 0, and hide the card until a night has ended. |
| "Times you put it down" counts "Never mind" taps. | Misleading | P2 | As on Tonight. |
| "Pauses used" on the sheet that asks for money reads as a tally of slips. | Rules | P3 | Drop it. Nights and closed apps are the facts about the person. |
| After "Keep it" or "Restore purchase", the button only greys out until Apple's sheet appears. | Feedback | P3 | A `ProgressView` in the button while `working`. |
| Done is the title "Every night is yours", seven full segments and "Done", with nothing about what happens now. | Vague | P3 | One line under it: "Dusk keeps locking your apps every night." |
| The segments' VoiceOver label is "Your free week", with no count. | Rules (AX) | P3 | "Night 5 of 7 free" (`Copy.Home.nightPill`). |
| D78: "Your free week", "7 nights free", "Start my free week", Ready's footnote and the seven segments all change. Fourteen segments won't fit Welcome's card at AX5 as drawn. | Polish | P3 | With #115: say "free nights", and draw two rows of seven. |

## Settings

`settings`, `settings-anywhere` and `settings-heads-up-denied`.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| "Only when I'm home · On" reopens the map, and nothing in Settings turns it off. The only way back to anywhere is Blocks › Your nights › Place › Use anywhere: another flow, with another picker. | Dead end | P2 | When home is set, offer "Use anywhere" in the sheet under the map. Route the night editor's Place row to the same flow (see Block editor). |
| The Location row ("While Using", "Off") does nothing, under the heading "Is everything working?", even when location is why home doesn't work. Screen Time's row offers "Turn on"; location offers nothing. | Dead end | P2 | When home is set and location isn't Always, make the row a `SettingsLink`. |
| "Last blocked · 10:30 pm – 7:00 am" has no day, and can be a Study block at 5 pm. | Vague | P2 | "Last night · Mon 10:30 pm – 7:00 am", from the night log. |
| "Restore purchase" has a chevron, though it's an action. On success nothing is said: `Copy.Settings.restored` ("Purchase restored.") is never shown. The row stays after purchase. | Feedback | P2 | Drop the chevron, show "Purchase restored." as the row's detail, and hide the row once purchased. |
| "Privacy" has a chevron but is static text in this build (`ui.json`: StaticText, not Button) because `TollPrivacyURL` is empty. "Contact" is a link with no chevron. | Inconsistent | P3 | Hide rows with no URL. Every link that leaves the app gets `arrow.up.forward.app`. |
| A "Blocks" row pushes a second copy of the Blocks tab, with a different back button. | Inconsistent | P3 | Remove the row; Blocks is a tab. |
| "How it works" is a sheet with no button. It closes only with a swipe, and at AX5 it's full height. | Dead end | P3 | A "Done" button in its actions. |
| At AX5 the rows stack, and the chevron sits alone on its own line under the detail (`ax5/settings`). | Polish | P3 | Keep the chevron trailing on the title's line at accessibility sizes. |
| The version appears only in "Activity log", which is removed before launch. | Polish | P3 | A quiet version line at the bottom of Settings. |
| Settings is reached only from Tonight's gear. | Polish | P3 | Accept (D63), or put the gear on every tab. |

## Your sleep

`insights`, `sleep-monday` and `sleep-best`.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| "214 h phone-free" adds up every block's hours, Study and Gym included. `InsightsSnapshot.hoursBlocked` reads every `blockOn` line. It's also not phone-free: everything off the list stayed open. This is the same family as the founder's "phone-free tonight" flag. | Misleading | P1 | Count the night only, and say what it measures: "61 h with apps locked at night". |
| "30 days" and "All time" read the transition log, which keeps 2,000 lines, about ten nights by `YourSleep`'s own comment. `sleep-best` shows "20 nights" in its first card and "51 h" over 30 days, about six nights' worth. | Misleading | P1 | Build the ranges from the night log (`nights.jsonl`, D62), which isn't trimmed. Or drop "All time" until then. |
| "23 nights" beside a moon has no noun. Nights of sleep? Nights tracked? Nights since installing? | Vague | P1 | "23 nights" over "with apps locked" (`Copy.Home.nightsLabel` exists). |
| The range picker sits under the week cards but only changes the stat and chart below it. It looks as if it scopes the whole tab. | Vague | P2 | A section header over it ("Over time"), or one fixed range ("Last 30 nights"). |
| "When you put it down" charts "Never mind" taps by hour, always 10 pm to 6 am. The title doesn't say what's counted, and a 12:30 – 8:30 am night loses its last two hours. | Vague | P2 | "When you closed a blocked app", with hours fitted to the night, as D60 fits the strip. |
| The chart is hidden from VoiceOver; only "Most at 11 pm" is read. | Rules (AX) | P2 | An `accessibilityChartDescriptor`, or a label with the peak and the total. |
| The picker's VoiceOver label is "Your nights" (`Copy.Insights.title`), the night editor's title, on the tab called Your sleep. | Inconsistent | P3 | "Range". |
| The tab is named Your sleep and shows no sleep yet; everything on it is about the lock. | Misleading | P3 | For product. No change before Health (#86) (D63, D65). |
| "6 nights this week · Your most in a week" repeats the six filled dots directly above it. | Wordy | P3 | Keep the card (D69), but title it by the fact the dots don't show: "Your most in a week". |

## Blocks

`blocks` and `blocks-day`.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| The night card and rows count a whole category as one app: "4 apps" (`Copy.Blocks.appCount(appCount + categoryCount)`). Ready says "2 categories · 2 apps". | Misleading | P2 | `Copy.Blocks.summary(categories:apps:sites:)` everywhere. |
| A block that isn't on says "Wed" or "Today" with a clock, and no time. "Wed" doesn't say "next on Wednesday", or when. | Vague | P3 | "Wed 9 am", "Today 6 pm". |
| The footnote "A pause opens every block at once." sits under the limits, out of context. | Vague | P3 | Move it to How it works. |
| "Sets of hours 3 of 8" is a limit people can't predict: blocks with the same hours share one. | Vague | P3 | When it's full, the New block row says what to do, as `Copy.Blocks.refused` does: "Use the same hours as another block." |
| With three blocks there's a band of empty screen between "New block" and the limits (D64). | Polish | P3 | Accept (founder's call). |

## Block editor

`block-new`, `block-new-gym`, `block-edit`, `block-edit-on` and `block-night`.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| "Name · Study" is a text field that looks like a plain row: right-aligned text, no field shape, no cursor until tapped. | Dead end | P2 | Give it the field look (`surfaceRaised`, 12 pt corners, as `TimeField`), or a pencil glyph. |
| The night's Place row opens the generic place search (Building / Street / Campus). Tonight and Settings set home with the map and "This is home". | Inconsistent | P2 | Route the night's Place row to `SetHomeFlow`. |
| For the night, the day chips mean "nights starting on". Weeknights are Sunday to Thursday, so the Monday-first row lights M T W T and the last S. That reads as Monday to Thursday and Sunday, and a lone "S" could be either day. | Vague | P2 | Label the row "Nights starting", and show the span under the chips ("Sun night → Mon morning"). |
| Onboarding sets the night by wake time; the editor shows From / Until, with no length. Changing Until silently changes how long the night is. | Inconsistent | P3 | Show the length under the fields ("8 h 30 m"), as the wake screen does. This matters more with D76's bed and lock times. |
| Editing a block that's on says "Changes apply when this block ends." in a note and again on the button ("Save for after 5:00 pm"). | Wordy | P3 | Keep the button and drop the note's second sentence. |
| The kind tiles' labels sit at three heights: Study and Work 395, Gym 398, Other 384 (`block-new`). | Polish | P3 | Fix the glyph frame height in `KindChips`. |
| "Your nights can be changed but not deleted." answers a question nobody asked. | Wordy | P3 | Drop it; there's no Delete button. |
| Cancelling Apple's picker after choosing a kind leaves Save disabled with no reason. | Feedback | P3 | The empty apps row's detail reads "Choose apps to save" while empty. |
| A held save leaves only a small "Changes apply at 7:00 am" on the row. | Feedback | P3 | Show that row's state in `accent` with the clock glyph until the change applies. |

## Onboarding

`welcome`, `wake`, `wake-weekends`, `screen-time*`, `blocklist` and `ready`.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| Ready's title is "Tonight at 10:30 pm.", a fragment that doesn't say what happens at 10:30. The time is repeated right under it, in the night picture. | Vague | P2 | "Apps lock tonight at 10:30 pm." (with D76, at the lock time). |
| Screen Time denied says "Turn it on in the next screen, or in Settings › Screen Time." There is no next screen: "Try again" asks Apple again. | Vague | P2 | "Tap Try again and choose Continue, or turn it on in Settings › Screen Time." |
| On Wake, the wheel sets the end, while "Change" on the row sets the start. The row's detail is the night's length, and "Change" doesn't say what it changes. | Vague | P2 | Name the links "Start" (weeknights) and "Wake" (weekends). |
| Ready's row "Blocked · 2 categories · 2 apps" reads as a state on a screen where nothing is blocked yet. | Misleading | P3 | "Apps to block" (`Copy.Blocks.apps`). |
| Ready is the first mention of pauses ("3 pauses a week · Every app opens for 10 minutes"), with no word about the wait. | Vague | P3 | "Each opens your apps for 10 minutes, after a 1-minute wait." |
| Ready's footnote: "Then $9.99 once, or it switches off." "It" is unclear. | Vague | P3 | "…or Dusk stops locking." |
| On Wake, Weeknights shows a length ("8 h 30 m") and Fri and Sat nights a span ("12:30 am – 9:00 am"). | Inconsistent | P3 | Show both rows the same way: the span, with the length after it. |
| "You can change this any time." doesn't say where. | Vague | P3 | "You can change this later in Blocks." |
| The wake wheel stays at its default size at AX5 (`UIDatePicker` wheels don't scale). | Rules (AX5) | P3 | Accept (system control), but check that the label beside it is read. |

## Only when I'm home

`set-home`, `set-home-off`, `set-home-location`, `set-home-always` and `set-home-location-off`.

| Issue | Type | Sev | Fix |
|---|---|---|---|
| "Choose Always" draws iOS's location list (Never, Ask Next Time, While Using the App, Always ✓) as rows that look tappable but are static text (`ui.json`). | Dead end | P2 | Draw it as a picture: a smaller inset image of the list, with no row chrome, captioned "In Settings". |
| After "This is home" during a night, the save waits for the night to end (B-3), and the sheet just closes. | Feedback | P2 | Settings' row reads "On from 7:00 am", and Tonight's hero line says the same. |
| Location denied reads "Never" in this flow and "Off" in Settings. | Inconsistent | P3 | One word: "Off". |
