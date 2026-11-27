# App Store listing and review notes

Dusk stands for the product name, not chosen yet (spec header). Copy rules from spec §8 apply here too: facts, numbers, no adjectives about the user. Checked against the app as it is after D97 and D98 (#132). When a screen's words change, change the steps below in the same pull request.

## Listing

- **Subtitle (30):** Your nights, phone-free *(assumed, #132: it is Welcome's title, so the listing and the first screen say the same thing; the alternative is "Buy back your sleep", the toll's line from before the pause replaced the door, D67)*
- **Promotional text:** 14 nights free. Then $9.99 once, or it switches off. No subscription.
- **Description:**

  > At night, the apps that keep you up stop opening. Everything else works.
  >
  > • Fit Dusk to your sleep. It can read when you usually fall asleep and wake from Apple Health, or you set the times yourself.
  > • Apps lock a while before you fall asleep and stay locked a while after you wake: 30 and 15 minutes to start. Each can grow by 15 minutes after a week with few pauses, up to 60 and 30, or stay where you set it.
  > • Pick the apps and sites that keep you up. Everything else stays open.
  > • Need a break? A pause opens blocked apps for 10 minutes, after a one-minute wait. You get 3 a week, back every Monday at noon.
  > • Only when you're home, if you like: set home once, and your night starts when you get there.
  > • In the minutes before sleep, three things to do with the phone down: tomorrow's list on paper, slow breathing with a soft tone, or a word game for bed.
  > • Each morning, last night in plain facts. Each night the apps stayed locked adds a star to your sky.
  >
  > 14 nights free. Then $9.99 once, or it switches off. No subscription. No account.
  >
  > No servers. Nothing you do in Dusk leaves your phone.

- **Keywords (100):** sleep,bedtime,night,screen time,app blocker,focus,phone,limit,block apps,wind down,routine
- **Category:** Health & Fitness (secondary: Productivity)
- **Age rating:** 4+
- **Privacy label:** Data Not Collected. The trial start date in iCloud Keychain (decisions D78) doesn't change it: Apple holds it end-to-end encrypted on the person's behalf, and the developer never receives it. Sleep read from Apple Health (#144) doesn't change it either: it stays on the device. Your sky's image goes only where the person sends it with the share sheet.
- **In-app purchase:** `com.advan.toll.full`, non-consumable, $9.99. Display name "Keep it". Description: "Keeps apps locking every night after the free nights."

## Review notes

Paste everything in the quote into App Store Connect's notes. No sign-in is needed.

> Dusk is a personal self-control tool for sleep. The person using it locks chosen apps on their own iPhone around their own sleep, with Screen Time's individual authorization. There is no parental or remote control, no account and no server: everything stays on the device. The app makes no network requests of its own; the only network use is StoreKit's purchase and restore.
>
> **Quickest way to a blocked night (about 3 minutes).**
> 1. On a fresh install, Welcome: tap "Start my 14 free nights".
> 2. "Fit Dusk to your sleep": tap "Set my hours myself" (or "Use Apple Health", see HealthKit below).
> 3. "When do you usually fall asleep and wake up?": set Fall asleep to about 20 minutes from now and Wake up a few hours later. Continue.
> 4. "The time around your sleep": leave it as recommended (30 minutes before sleep, 15 after waking). Apps therefore lock at once, 30 minutes before the sleep time you set. Continue.
> 5. "Allow Screen Time": tap Allow, then Continue on Apple's sheet, then Continue.
> 6. "What keeps you up?": tap "Choose apps", pick any app (Safari or Calendar will do), Done, Continue.
> 7. Ready says "From now until …". Tap Done. Tonight shows "Apps locked until …".
> 8. Open the app you picked: the block screen says "Blocked until …", with "Never mind" and "Open Dusk to pause".
>
> **The pause.** The only way to open blocked apps early, and it is limited on purpose. Tap "Pause" on Tonight, or "Open Dusk to pause" on the block screen, which opens Dusk at the same sheet; then "Pause for 10 min". A 60-second wait follows, which costs nothing to cancel. Then every blocked app opens for 10 minutes and locks again on its own, with the app open or closed. "Lock again" within the first 2 minutes gives the pause back. There are 3 a week, back every Monday at noon. There is no button that ends the night early.
>
> **The time around sleep.** The person sets when they fall asleep and wake. Apps lock a buffer before sleep (30 minutes to start) and stay locked a buffer after waking (15 minutes). Unless the person fixes them in Settings › Sleep, each can grow by 15 minutes after a week with few pauses, up to 60 and 30, and shrinks by 15 after a week with 2 or more pauses in it. The change is made at Monday noon, on the device, even with the app closed; Tonight then says the new time once.
>
> **What the purchase sells (3.1.1, 4.10).** The one-time purchase pays for the app's own function: locking the chosen apps every night around the person's sleep, with the buffers, the pause, home and the morning facts. It does not sell access to Screen Time or to blocking as such.
>
> **Free nights (3.1.1).** Welcome states the terms before anything else: "14 nights free. Then $9.99 once. No subscription. No account." Under the main button, "Buy it now · $9.99" buys at once through the App Store sheet; bought or cancelled, setup goes on. "Already bought it? Restore" restores. The 14 nights start when setup ends. Their start date is kept in the Keychain and as an iCloud Keychain item, so deleting the app or moving to a new iPhone on the same Apple Account continues the same free nights; it is only a date, and there is no server. After them, without the purchase, nothing is blocked and the app says so. Nothing is charged automatically.
>
> **Family Controls (Screen Time).** The app asks for individual authorization (`.individual`), for the person's own phone. Three extensions use it: the DeviceActivity monitor starts and ends the night at its times with the app closed (and wakes once a day just after noon so Monday's change applies that night), the shield configuration draws the block screen, and the shield action handles its two buttons.
>
> **App Groups.** The app and its three extensions share one state file and logs on the device, in the App Group container. Nothing in it leaves the phone.
>
> **Location (5.1.1, 5.1.5, 2.5.4).** Optional, and never asked at launch or in setup. After setup, Settings › "Only when I'm home" (or a card on Tonight after the first night) shows a map; "This is home" asks for While Using, then for Always. Location is used for one thing: whether the phone is inside one circle around the home the person confirmed, so the night can wait until they're home with the app closed. That is why it asks for Always. The app keeps one yes or no, never a history, and stores no coordinates but the home point. Without location, the night runs at its set times wherever the person is, and every paid feature works.
>
> **HealthKit (2.5.1, 5.1.1, 5.1.3).** Dusk reads one type, Sleep Analysis, and only after the person taps "Use Apple Health" on "Fit Dusk to your sleep" (or the same screen later, for people already using Dusk). It requests no write access and writes nothing to Health. It uses the sleep to suggest when the person usually falls asleep and wakes, and adds each night's sleep to the person's own night log on the device. Nothing read from Health leaves the iPhone, and it is never used for advertising. "Set my hours myself" skips Health, and every feature works without it. To see it: on a fresh install, "Start my 14 free nights", then "Use Apple Health"; with at least 7 recent nights of sleep in Health, the next screen shows the usual times; with fewer, it asks for them.
>
> **Background audio (2.5.4).** The audio background mode is for one thing: the breathing tone before sleep. While apps are locked and before the sleep time, Tonight shows a small "Before sleep" button. It offers "Write tomorrow's list", "Breathe for 3 minutes" and "Try this in bed". "Breathe" makes a soft tone on the phone (no file, no network), rising and falling about six times a minute, and asks the person to lock the phone and put it down. The tone keeps playing with the screen locked for the length they set (1 to 10 minutes), then fades and stops, and the audio session is released. Nothing else plays, and nothing starts without a tap. To hear it: follow the quickest way above, so apps lock 30 minutes before sleep; tap "Before sleep" on Tonight, then "Breathe for 3 minutes", and lock the phone. Settings › Sleep › "Something to do before sleep" turns the helpers off.
>
> **Notifications.** One local notification, if the person turns it on: "Apps lock in 20 min", before each night. It is offered after the first night, on Tonight or in Settings, never at launch. No push, no server.
>
> **Sharing.** At 7, 30, 100 and 365 nights, the morning card offers "Share": an image of the person's sky and the number of nights, made on the phone and handed to the system share sheet. Nothing is sent unless the person sends it.
>
> **Encryption.** The app uses no encryption beyond the operating system's (`ITSAppUsesNonExemptEncryption` is false).
>
> The night ends at its set time plus the buffer after waking, when the person leaves home (if they set home), or after the free nights without the purchase.

## Capabilities and where the notes cover them

Every entitlement and Info.plist key in `ios/Config/` has a sentence above. A change to either file changes this table and the notes.

| Capability | Where it's declared | Notes paragraph |
|---|---|---|
| Family Controls | `App.entitlements`, `Extension.entitlements` (`com.apple.developer.family-controls`) | Family Controls |
| App Groups | both entitlements files, `TollAppGroup` in every Info.plist | App Groups |
| HealthKit, read only | `App.entitlements` (`com.apple.developer.healthkit`), `NSHealthShareUsageDescription` | HealthKit |
| Location, While Using and Always | `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` | Location |
| Background audio | `UIBackgroundModes` `audio` | Background audio |
| Export compliance | `ITSAppUsesNonExemptEncryption` false | Encryption |
| In-App Purchase | App ID capability; no entitlement key | Free nights, What the purchase sells |
| Keychain and iCloud Keychain | none needed (the app's own access group) | Free nights |
| Local notifications | none needed | Notifications |
| Three extensions | `NSExtension` in `Monitor-`, `ShieldAction-`, `ShieldConfig-Info.plist` | Family Controls |
