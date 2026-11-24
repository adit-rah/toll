# The plain-language pass

Every string changed by the plain-language and naming pass (D65, D68, D70), with its reason. The rules it applies:
- **Plain words.** Everyday words ("blocked", "open", "night", "pause") are fine. Dusk-only terms or phrases that need learning are not: "door", "unlock" as a currency, a block called "Sleep", "sleep window", "time windows" as a quota.
- **The night.** Its hours are "Night", "Tonight" and "Your nights" (D68).
- **One word, one concept.** "Pause" is the escape (D67). "Off" is the free week ended. "Block" is the app's own word.
- **Feel good from true numbers (D65).** No shortfalls ("5 of 7"), no week-against-week comparison unless it's better, and no population norms.
- **About the person, not the app's work.** "You put it down", not "it stopped you".

`CopyTermsTests` keeps the banned terms out of `Copy`: "door", "unlock", "sleep window", "sleep hours", "time window", "bedtime", "streak", "missed", "!", "great", "awesome" and "most adults". Exceptions are listed in the test with a reason; there are none today.

## Strings

| Where | Before | After | Why |
|---|---|---|---|
| Tonight hero, block rows (`Home.paused` → `Home.off`) | Paused | Off | The free week ending isn't a pause. "Pause" is the escape's word (D67, D70). |
| Tonight hero, no night ahead (`Home.noBlocks`) | No blocks | Nothing scheduled | Says what's true. The night isn't a block to people (D68). |
| Tonight's strip, VoiceOver (`Home.timelineLabel`) | Tonight's block, 10:30 pm to 7:00 am | Tonight, 10:30 pm to 7:00 am | The night isn't a block (D68). |
| Tonight's location note (`Home.locationBanner`), location facts (`Setup.whileUsingFact`, `approximateFact`, `deniedFact`) | … Your night runs on its hours, wherever you are. | … Your night starts and ends at its set times, wherever you are. | "Runs on its hours" needs learning. This says what happens. |
| Location off screen title (`Setup.locationOffTitle`) | Your night runs on its hours | Your night keeps its set times | Same. |
| Map, location denied (`Setup.homeWithoutLocation`) | Location is off, so your night runs on its hours, … | Location is off, so your night starts and ends at its set times, … | Same. |
| Choose Always (`Setup.alwaysLine`) | … Without it, the night runs on its hours, wherever you are. | … Without it, your night starts and ends at its set times, wherever you are. | Same. |
| Choose Always, quiet button (`Setup.alwaysLater`) | Not now. The night runs on its hours. | Not now. Use the set times. | Same. |
| Location tile (`Setup.locationWhy`) | So the night knows when you're home | So your night starts when you're home | Says what it does for the person, not what the app knows. |
| Anywhere row (`Setup.anywhereDetail`) | Runs on its hours, wherever you are | At its set times, wherever you are | "Runs on its hours" needs learning. |
| Place picker, no place (`Blocks.anywhereNote`) | … starts and ends on its hours alone. … | … starts and ends at its set times. … | Same. |
| Wake time footnote (`Setup.sleepAdvice`) | Most adults need 7 to 9 hours. You can change this any time. | You can change this any time. | Population norm (D65). The night's length is on the row above. |
| Welcome title (`Setup.welcomeTitle`) | Buy back your sleep. | Your nights, phone-free. | An idiom that reads as paying for sleep and doesn't translate. Uses the morning card's "phone-free" (D69). |
| Ready, free week used (`Setup.freeWeekEnded`) | The free week ended Sunday. Blocks start after the $9.99 purchase. | The free week ended Sunday. Nothing is blocked until the $9.99 purchase. | The night isn't a block (D68). |
| Night's stored name (`Setup.sleepName` → `nightName`) | Sleep | Night | It's never shown, but if it leaks it's the night, not a block called "Sleep" (D68). The migration uses it too. |
| Block screen, the night (`Shield.subtitle`) | It's your sleep time. | This app is blocked for the night. | "Sleep time" is a name for the hours (D68). This matches the other blocks' "This app is blocked during Study." |
| Your sleep, range picker (`Insights.week`, `month`, `all`) | Week · Month · All | 7 days · 30 days · All time | "Week" read as the Monday-to-Sunday week on the same screen. |
| Your sleep, hours stat (`Insights.hoursLabel`) | 161 h blocked at night | 161 h phone-free | About the person, not the app's work (D65). It counts any block's hours, so "at night" wasn't always true. |
| Your sleep, week bars (`Insights.stopped`, `weekLabel`) | Times it stopped you · Week 1 … Week 4 | (removed) | Frames the app's work, and set this week against earlier weeks whether or not it was better (D65). |
| Your sleep, by hour (`Insights.when`) | When it stopped you | When you put it down | About the person (D65). |
| Purchase sheet, nights (`Home.nightsBlocked`, `nightsBlockedLabel` → `nightsLabel`) | 5 of 7 · nights blocked | 5 · nights phone-free | "5 of 7" is a shortfall (D65). |
| Purchase sheet, taps (`Home.stoppedLabel` → `putDownLabel`) | 3 · times it stopped you | 3 · times you put it down | About the person (D65), and the morning card's words (D69). |
| Purchase sheet footnote (`Purchase.footnote`) | Without it, nothing is blocked. Your blocks and settings stay. | Without it, nothing is blocked. Everything you set up stays. | The night isn't a block (D68). |
| Settings, last stretch (`Settings.lastNight`) | Last night | Last blocked | It's the latest stretch any block was on, which in the day can be Study's. |
| Settings, its value (`Settings.blocked`) | Blocked 10:30 pm – 7:00 am · Blocked from 10:30 pm | 10:30 pm – 7:00 am · Since 10:30 pm | The title already says it. |
| Settings, Blocks row (`Settings.blocksSummary`) | 2 blocks · 7 of 40 apps and sites | 7 of 40 apps and sites | "2 blocks" counted the night as a block (D68). The limit is the number that matters. |
| Settings, free week (`Settings.freeNights`) | Free nights · Night 5 of 7 | Free week · Night 5 of 7 | "Free week" is the name everywhere else. |
| Settings, bought (`Settings.purchased`, new `purchasedDetail`) | Free nights · Purchased | Purchased · Every night, for good | "Free nights · Purchased" read as a contradiction. The detail is the purchase sheet's first line. |
| Settings, help (`Settings.howItWorks`) | How blocking works | How it works | The sheet is about the night now. |
| How it works, lines (`Settings.howItWorksLines`) | A block is on when you're at its place, in its hours. · Apps on its list don't open. Everything else works. · (pause line) · Without location set to Always, blocks run on their hours, wherever you are. | During your night, the apps you chose don't open. Everything else works. · With home set and location on Always, your night starts once you're home. Otherwise it starts and ends at its set times, wherever you are. · (pause line, unchanged) · Other blocks work the same way, on their own hours. | Leads with the night (D65, D68). Says home is optional (D68). |
| Settings, testing only (`Settings.log`) | Transition log | Activity log | "Transition" is the code's word. |
| Blocks limits (`Blocks.timeWindows`) | Time windows · 3 of 8 | Sets of hours · 3 of 8 | "Time windows" is a quota term that needs learning. Blocks with the same hours share one set. |
| New block, full (`Blocks.windowsFull`) | Up to 8 time windows across all blocks. | Up to 8 sets of hours across all blocks. | Same. |
| Block editor, refused (`Blocks.refused`, too many windows) | Too many different hours across blocks. Share hours with another block. | Too many sets of hours across blocks. Use the same hours as another block. | Same words as the limit. |
| Blocks footnote (`Blocks.unlocksShared`) | Pauses are shared by all blocks. | A pause opens every block at once. | Says what a pause does, which is what matters when there are several blocks (D67). |
| Place picker size (`Blocks.street`) | Block | Street | "Block" is the app's word for a block. One word, one concept (D57). |
| Always location purpose string (Info.plist) | Starts and stops the night's block when you get home or leave, with the app closed. … | Starts your night when you get home and stops it when you leave, even with the app closed. … | The night isn't a block (D68). |

## Removed, unused

These had no caller. They were deleted so the scan and the next pass read only what's on screen:
- **`Copy.Trial`:** "Seven nights.", "Blocked at home: N nights", "Block screen came up: N times", "Pauses used: N", "Keep it — $9.99 once", and its restore, pending and failed lines. The purchase sheet replaced them.
- **`Copy.offer`:** "Seven nights free. Then $9.99 once, or it switches off. No subscription."
- **`Purchase.unlocksUsedLabel`:** "pauses used".

## Not words

- **Off's symbol.** The trial-ended state's symbol is `TollSymbol.off` (`power`), not `pause.circle`, wherever "Off" shows: Tonight's hero, block rows, and nights after the free week in the week dots (design §2.6). `HomeSnapshot.Hero.paused` and `Timeline.Phase.paused` are now `.off`. A block row's `paused` state is merged into `off`: it was drawn and worded the same.
- **Glyphs on the stats.** The purchase sheet's three counts carry the moon, `iphone.slash` and `pause`, and Your sleep's hours carry `iphone.slash`, so each number says what it counts without its label.

## Kept, and why

- **"Paused"** (`Door.isOpen`): the pause is open. That's the only "Paused" left.
- **"Pause in Dusk"** (block screen) and **"Never mind"**: plain. iOS can't start the wait from the block screen, so the button says where it goes.
- **"Lock again"**: an everyday word for blocking again. It matches the lock glyph.
- **"Night 3 of 7 free"** (pill), **"Night 5 of 7"** (Settings): where you are in the free week, not a shortfall.
- **"N nights last week"** on a new week: a fact about your own past, not set against this week.
- **"Your most in a week"**: shown only when this week beats every earlier week (D69). It's a fact, not praise.
- **"Every night is yours"** (after buying): the founders' words (D59).

## Tonight says what its times mean (D75)

The founder's review of Tonight (24 Nov 2026): an eyebrow must say what the big time is, and a quantity must say what it counts.

| Where | Before | After | Why |
|---|---|---|---|
| Tonight, evening eyebrow (`Home.locksAt`, `locksTomorrowAt`, `locksOn`) | Tonight | Apps lock at · Apps lock tomorrow at · Apps lock Monday at | "Tonight" didn't say what the time was. A start that isn't tonight names its day. |
| Tonight, evening (`Home.phoneFree`) | 8 h 30 m phone-free tonight | (removed) | Read as time off the phone today, not the night's length. |
| Tonight, blocked eyebrow (`Home.blockedUntil`) | Blocked until | Apps locked until | Pairs with "Apps lock at". |
| Tonight, blocked line (`Home.youreHome`) and the dots (`Door.pausesOf`) | You're home · 3 pauses left (or On now · 3 pauses left) | You're home (or nothing), and "3 of 3 left this week" beside the dots | "On now" repeated the eyebrow, and the line repeated the dots without saying over what period (the audit). |
| Tonight, "Pause" capsule, VoiceOver (`Home.pauseSpoken`) | Pause | Pause blocking | "Pause" alone had no object (the audit). |
| Tonight, while a pause is open (`Home.lockAgain`) | (the sheet only) | Lock again, a capsule by the dots | The pause sheet can be swiped away now; the hero keeps its one action (the audit). |
| Tonight, pause open (`Home.pausedUntil`, `thenLockedUntil`) | Blocked until 7:00 am | Paused until 11:52 pm · Then locked until 7:00 am | The apps were open; the hero said they were blocked. |
| Tonight, away (`Home.nightEndsAt`, `locksWhenHome`) | Tonight · 10:30 pm · Starts when you're home | Night ends at · 7:00 am · Apps lock when you're home | The time shown had already passed. |
| Tonight, away, the pill (`Home.awayLabel`) | Away from home | (removed) | The hero says it with the same glyph; a capsule on Tonight is something to tap (the audit). |
| Tonight, off card (`Home.turnBackOn`, `onceEveryNight`) | Turn it back on · $9.99 once · every night after | Turn Dusk back on · $9.99 once, for good | "Every night after" read as a charge each night, and "it" wasn't named (the audit). Its tile is Off's power glyph. |
| Tonight, Screen Time off line (`Home.screenTimeOffDetail`) | Turn it on to block tonight. | Nothing blocks tonight | The card above already says how to turn it on (the audit). |
| Tonight, nothing scheduled (`Home.setNight`) | (no way forward) | Set your night | A dead end (the audit). The pill hides too. |
| Tonight, the strip under the morning card (`Strip.tonightAt`) | (no label) | Tonight 10:30 pm, over the night | The card is last night and the strip is today; the label says which night is which (the audit). |
| Tonight, without location (`Home.anywhereStartsIn`) | Starts at 10:30 pm, wherever you are | Anywhere · starts in 2 h 35 m | The start is already the big time. Same words as home not set. |
| Tonight, a start days away (`Home.duration`) | Starts in 55 h 30 m | Starts in 2 d 7 h | Readable at a glance. |
| Tonight, off eyebrow (`Home.isOff`) | Off | Dusk is off | Says what's off. |
| Tonight, Screen Time eyebrow (`Home.screenTimeOffEyebrow`) | Screen Time off | Screen Time is off | A sentence, like the others. |
| Tonight, nothing scheduled eyebrow (`Home.yourNight`) | (empty) | Your night | Every eyebrow says what the line under it is about. |
| Morning card eyebrow (`Morning.lockedLastNight`) | Last night | Apps locked last night (when it ran) | Says what the bar and its times are. Away or Screen Time off keeps "Last night". |
| Purchase sheet, nights (`Home.nightsLabel`) | 5 · nights phone-free | 5 · nights with apps locked | Counts nights the apps were locked, not time off the phone. |
| Your sleep, hours (`Insights.hoursLabel`) | 161 h phone-free | 161 h locked at night | Locked hours, not time off the phone, and now only the night's: Study and Gym hours aren't sleep (the audit, the founder). |
| Your sleep, the count (`YourSleep.nights`) | 23 nights | 23 nights locked | Nights of what (the audit; the founder's words). |
| "Never mind" taps (`Morning.putDown`, `Home.putDownLabel`, `Insights.when`) | You put it down 3 times · 3 times you put it down · When you put it down | You chose sleep 3 times · 3 times you chose sleep · When you chose sleep | Closing a blocked app isn't putting the phone down, and "it" had no referent (the audit; the founder's words). |
| Back button from Tonight (`Home.backTitle`) | Home | Tonight | "Home" is also the place. |
| The pill, VoiceOver hint (`Home.pillHint`) | (none) | Shows your free week and the price | The pill now opens the purchase sheet. |
| The strip and its snippet (`Copy.Strip`) | Tonight, 10:30 pm to 7:00 am | Your night, 10:30 pm – 7:00 am, 4 apps, Home, Tonight · Edit | Each segment is a button with its snippet. |
