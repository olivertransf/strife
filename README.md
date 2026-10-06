# Strife

A 3D board game in Godot 4.5. Four cars move along the track from the first fork to retirement. The rules follow the current Hasbro Game of Life (E4304): college or career, family or life, risky or safe, houses, pets, babies, loans, and a 1–10 spinner.

This is not a Hasbro product. Card names and sentences are original. The amounts (tuition, payday bonus, loans, retirement order, what a baby or a kept card is worth) match the published [E4304 game guide](https://instructions.hasbro.com/en-us/instruction/the-game-of-life-game).

## Play

Open the project in Godot 4.5 and run `Scenes/main.tscn`.

You are the first car. Blair, Casey, and Drew play themselves with the same choice policy the tests use. Spin, pick a path, and read the card. The camera follows the car, leans in for a card or a fork, and pulls back for the final tally.

Money is in thousands. Everyone starts with 200K.

- **Career** draws two jobs and keeps one. **College** pays 100K now and picks a higher-paying job at Graduation.
- Passing a Payday space pays your salary. Landing pays the salary plus 100K.
- A STOP space ends the move. You resolve it, then spin again.
- Houses can be bought, sold, or skipped. A sale spins red (1–5) or black (6–10).
- The wheel: everyone picks a number, the player who landed picks a second, and the spinner pays 200K when it hits a picked number.
- If you cannot pay, the bank loans 50K. Paying a loan back costs 60K.
- Retirement pays 400K, 300K, 200K, then 100K, in the order people arrive. Then houses are sold, kept Action and Pet cards are worth 100K each, each baby is worth 50K, and leftover loans come off. The richest total wins.

## Check without playing

Godot is expected at `/Applications/Godot.app/Contents/MacOS/Godot`.

```bash
./check_game.sh
```

That runs two headless passes. Both must print `RESULT ok` and exit 0.

- `--rules` checks payday (pass versus land), STOP cutting a move short, college tuition and graduation, the career draw, 50K loans repaid at 60K, the 200K wheel, baby and card values, retirement order, and red versus black house sales. It also checks that every space on the track is reachable, every fork is a STOP, and both retirement parks are dead ends.
- `--sim --games 30 --seed 1` plays thirty full games with the shared policy and writes `artifacts/sim.json`.

Screenshots, still with nobody at the keyboard:

```bash
./check_game.sh capture
```

That opens a window, plays a seeded game, and saves `artifacts/captures/` (`opening`, `move`, `card`, `wheel`, `fork`, `scoreboard`).

The play scene and the simulator call the same rules API in `Scripts/life/`. The 3D scene only animates events the rules already resolved.

## Layout

- `Scenes/main.tscn` is the track. Space markers stay where they are. `Data/board_spaces.json` tags each one at load.
- `Data/*.json` holds the career, college, action, house, and pet decks.
- `Scripts/life/life_rules.gd` is the rules. `life_policy.gd` is the shared chooser. `life_tests.gd` is the headless check.
- `Scripts/main.gd` runs a turn. `board_view.gd`, `hud.gd`, and `camera_3d.gd` are the board, cards, and camera.

An in-editor agent can also drive Godot through [Godot MCP](https://github.com/ee0pdt/Godot-MCP) or [godot-mcp](https://github.com/Coding-Solo/godot-mcp). The headless script above is the check that does not need the editor open.
