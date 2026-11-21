# Teams and tickets

Work is tracked in GitHub issues, one ticket per piece of work, each labelled with the team that owns it and a priority. A ticket should carry everything its team needs to start without reading the conversation that produced it: the problem in plain terms, where things stand in the code, what to build or decide, and what comes back.

## Teams

| Label | Owns | Hands off to |
|---|---|---|
| `team:software-engineering` | The app, its extensions and packages; tests in TollCore; renders; releases | QA for device checks |
| `team:design` | The design canvas (boards), copy tone, layout and motion rules (`docs/design.md`) | Software engineering, once a board exists |
| `team:data-science` | The sleep-timing model (`datascience/`, `ios/Packages/SleepModel`), the night-record schema, measures and simulations | Software engineering for app-side data; product for findings |
| `team:product` | Decisions the founders make: rules, pricing, what counts, App Review framing | Whichever team builds the answer |
| `team:qa` | Checks only a real iPhone can do (`docs/device-protocol.md`) | Software engineering, with results |

Product and QA tickets are closed in conversation with the founder: the agent asks the questions (a decision with its options, or a device check with what to look for), the founder answers, and the agent records the answer (a D-number in `docs/decisions.md`, or the result in `docs/device-protocol.md`), builds what follows, and closes the ticket.

A ticket can have more than one team; the first listed in the ticket body goes first.

## Priorities

| Label | Meaning |
|---|---|
| `P0` | Broken for users now; drop other work |
| `P1` | Before testers rely on it |
| `P2` | Soon; makes the product better or unblocks other work |
| `P3` | When convenient |

## How a ticket moves

1. Filed with a team and a priority, and linked to the issue or PR it came from.
2. A decision the ticket needs goes in `docs/decisions.md` (next free D-number) and is cited in the PR.
3. The PR says which ticket it fixes and lists anything left over as new tickets, so the original can close.
4. Device behaviour goes to QA as a row in `docs/device-protocol.md`, collected in a QA ticket.
