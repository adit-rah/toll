# Brief for design: realigning the Dusk screens (19 Nov 2026)

Thank you for the canvas. Engineering is building from it. These are the changes we need, and the reasons, so the next round matches what ships. Where a screen is not mentioned, build it as drawn.

## Product decisions that change the screens

1. **Price is $9.99 once.** Replace $24.99 everywhere: Welcome, Ready, Home trial states, Paused, Purchase, Settings.
2. **Name: Dusk** (working). Support address and domain to follow; keep `help@dusk.app` as a placeholder.
3. **Multiple blocks are in.** Sleep plus blocks like Study, each with its own place, hours, days and apps. Unlocks are shared. Limits the UI must state or prevent: **40 apps and sites across all blocks**; at most **8 different time windows** in total; Sleep can be edited but never deleted.
4. **No selling at night, and nothing in the user's face during the trial.**
   - Daytime pill: "Night 5 of 7 free" (quiet, not a button).
   - Last day: the pill reads "Last free night tonight" and opens the purchase sheet when tapped. Please remove the "Keep it for $24.99" button from *Home · trial ending*.
   - After the trial: *Home · paused* as drawn, with one calm card, "Turn it back on · $9.99 once".
   - The purchase sheet opens only from that card, the last-day pill, and Settings.
5. **Location without Always still works.** App Review requires that what people pay for does not depend on location. Without Always (or with Precise off), blocks run on their hours alone, wherever the user is.
   - Replace "Tonight's block may not start" with a fact: **"Location is set to While Using. Your blocks run on their hours, wherever you are."** Keep "Fix in Settings".
   - On *Location: Always*, the quiet option becomes **"Not now. Blocks run on their hours alone."**
6. **The door is 5 minutes on the clock, not 5 minutes of use.** iOS never tells an app live usage, so "48 s used" can't be shown truthfully. *Door · open* gets a countdown instead ("4:12 left"). The regret line stays as drawn ("Lock again in the next 1:12 and you keep the unlock").
7. **Drop *Try it*.** The test block can't be timed reliably and adds a step.

## The block screen is drawn by iOS

We supply a solid background colour (with an optional system blur), one icon, a title, a subtitle, a primary and a secondary button, and their colours. There's no gradient, no custom layout, no second line of buttons.
- Following Opal's pattern: the **primary button is "Never mind"** (closes the app), the **secondary is "Unlock in Dusk"** (opens Dusk at the door).
- Title per block: "Blocked until 7:00 am" for Sleep, "Study · until 5:00 pm" for others.
- Please redraw *Block screen* within those limits.

## "Phone after bedtime" is drawn by Apple, inside our app

Apple's Screen Time numbers can only be shown in a view iOS draws for us. Our code never sees the number. So that figure must be a self-contained tile, with no trend arrow computed by us, and it can't feed our charts. Everything else on Home and Insights comes from our own log and works as drawn. "Times it stopped you" counts taps on the block screen's buttons, so it undercounts, as your note says.

## Light and dark

Dark is the default; Settings gets **Appearance: Dark · Light · Match iPhone**. We have *Home · light*; please give us the light tokens, or approve deriving every other screen from it.

## States we need drawn

- **Setup:**
  - Screen Time denied (row says so, button "Try again").
  - Location denied or Approximate (the fact line above, button "Continue").
  - *Different on weekends* turned on (a second wake time).
- **Blocks:**
  - The block editor's app list after picking, with whole categories.
  - Over 40 apps ("Up to 40 apps and sites across all blocks").
  - Deleting a block.
  - An edit made during an active block ("Changes apply when this block ends").
  - A block that is on right now, in the list.
  - Place "Anywhere" for a block with no place.
- **Door:**
  - Picking more than one app ("Choose one app").
  - The countdown described above.
- **Purchase:** pending (Ask to Buy), failed, restore found nothing.
- **Settings:** an Appearance row, a Blocks entry if Home's list is the only way in, and the Transition log row while we test (it goes before launch).

## Copy rules (unchanged)

Facts, numbers or questions. Words a first-time user knows. No adjectives about the user. Times in the phone's 12- or 24-hour format.
