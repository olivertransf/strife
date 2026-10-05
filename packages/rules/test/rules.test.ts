import { describe, expect, it } from "vitest";
import { boardProblems, standardBoard } from "../src/board";
import { standardDecks } from "../src/decks";
import { createGame, dispatch, spinPrompt } from "../src/game";
import { babiesFromSpin, spinColor } from "../src/spinner";
import type { Board, Decks, GameState, Rng, Space } from "../src/types";

function spins(...values: number[]): Rng {
  let index = 0;
  return () => {
    const value = values[index];
    index += 1;
    if (value === undefined) throw new Error("spinner sequence exhausted");
    return (value - 1) / 10 + 1e-9;
  };
}

function space(partial: Pick<Space, "id" | "kind"> & Partial<Space>): Space {
  return {
    next: [],
    x: 0,
    y: 0,
    label: partial.label ?? partial.id,
    ...partial,
  };
}

function boardFrom(spaces: Space[], entry = spaces[0]?.id ?? "start"): Board {
  return {
    spaces: Object.fromEntries(spaces.map((entrySpace) => [entrySpace.id, entrySpace])),
    entries: { career: entry, college: entry },
  };
}

function decksWith(patch: Partial<Decks> = {}): Decks {
  return { ...standardDecks(), ...patch };
}

const players = [
  { name: "Ada", color: "red" as const, petName: "Miso" },
  { name: "Bea", color: "blue" as const, petName: "Dot" },
];

function seat(
  board: Board,
  decks: Decks,
  paths: Array<"college" | "career"> = ["career", "career"],
): GameState {
  let state = createGame({ players }, () => 0, { board, decks, shuffle: false });
  for (const path of paths) {
    state = dispatch(state, { type: "choosePath", path }, () => 0);
    if (state.phase === "pickCareer") {
      const card = state.offered[0];
      if (!card) throw new Error("no career offered");
      state = dispatch(state, { type: "pickCard", cardId: card.id }, () => 0);
    }
  }
  return state;
}

function playSpin(state: GameState, rng: Rng): GameState {
  let next = dispatch(state, { type: "spin" }, rng);
  let guard = 0;
  while (next.phase === "moving") {
    next = dispatch(next, { type: "commitStep" }, rng);
    if (++guard > 30) throw new Error("move did not finish");
  }
  return next;
}

describe("spinner", () => {
  it("colors odd numbers red and even numbers black", () => {
    expect(spinColor(1)).toBe("red");
    expect(spinColor(9)).toBe("red");
    expect(spinColor(2)).toBe("black");
    expect(spinColor(10)).toBe("black");
  });

  it("maps the baby stop table", () => {
    expect([1, 2, 3].map(babiesFromSpin)).toEqual([0, 0, 0]);
    expect([4, 5, 6].map(babiesFromSpin)).toEqual([1, 1, 1]);
    expect([7, 8].map(babiesFromSpin)).toEqual([2, 2]);
    expect([9, 10].map(babiesFromSpin)).toEqual([3, 3]);
  });
});

describe("board", () => {
  it("reaches retirement from both openings", () => {
    expect(boardProblems(standardBoard())).toEqual([]);
  });
});

describe("opening", () => {
  it("charges college tuition and deals two careers", () => {
    const decks = decksWith({
      career: [
        { id: "c1", kind: "career", name: "Driver", salary: 20 },
        { id: "c2", kind: "career", name: "Cook", salary: 30 },
        { id: "c3", kind: "career", name: "Nurse", salary: 40 },
      ],
    });
    let state = createGame({ players }, () => 0, {
      board: boardFrom([space({ id: "retire", kind: "stop", stop: "retirement" })]),
      decks,
      shuffle: false,
    });
    state = dispatch(state, { type: "choosePath", path: "college" }, () => 0);
    expect(state.players[0].cash).toBe(100);
    expect(state.players[0].job).toBeNull();
    expect(state.players[0].loans).toBe(0);
    state = dispatch(state, { type: "choosePath", path: "career" }, () => 0);
    expect(state.offered.map((card) => card.id)).toEqual(["c1", "c2"]);
    state = dispatch(state, { type: "pickCard", cardId: "c2" }, () => 0);
    expect(state.players[1].job?.id).toBe("c2");
    expect(state.decks.career.map((card) => card.id)).toEqual(["c3", "c1"]);
    expect(state.phase).toBe("awaitSpin");
    expect(state.current).toBe(0);
  });
});

describe("movement", () => {
  it("pays salary for a pass and salary plus 100K for a landing", () => {
    const track = boardFrom([
      space({ id: "act", kind: "action", next: ["pay1"] }),
      space({ id: "pay1", kind: "payday", next: ["pay2"] }),
      space({ id: "pay2", kind: "payday", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
      action: [
        {
          id: "quiet",
          kind: "action",
          name: "Quiet day",
          text: "Nothing happens.",
          effect: { type: "bankPays", amount: 0 },
        },
      ],
    });
    const landed = playSpin(seat(track, decks), spins(1));
    expect(landed.players[0].spaceId).toBe("act");
    expect(landed.players[0].actions).toHaveLength(1);
    expect(landed.players[0].cash).toBe(200);

    const passed = playSpin(seat(track, decks), spins(2));
    expect(passed.players[0].spaceId).toBe("pay1");
    expect(passed.players[0].actions).toHaveLength(0);
    expect(passed.players[0].cash).toBe(340);

    const across = playSpin(seat(track, decks), spins(3));
    expect(across.players[0].spaceId).toBe("pay2");
    expect(across.players[0].cash).toBe(380);
  });

  it("stops on a stop space even when the spin is longer", () => {
    const track = boardFrom([
      space({ id: "a", kind: "action", next: ["b"] }),
      space({ id: "b", kind: "action", next: ["grad"] }),
      space({
        id: "grad",
        kind: "stop",
        stop: "graduation",
        next: ["pay"],
        label: "Graduation",
      }),
      space({ id: "pay", kind: "payday", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
        { id: "job-c", kind: "career", name: "Nurse", salary: 40 },
      ],
      collegeCareer: [
        { id: "doc", kind: "collegeCareer", name: "Surgeon", salary: 100 },
        { id: "law", kind: "collegeCareer", name: "Counsel", salary: 80 },
      ],
    });
    let state = seat(track, decks, ["college", "career"]);
    expect(state.players[0].cash).toBe(100);
    state = playSpin(state, spins(10));
    expect(state.players[0].spaceId).toBe("grad");
    expect(state.phase).toBe("pickCareer");
    expect(state.players[0].cash).toBe(100);
    state = dispatch(state, { type: "pickCard", cardId: "law" }, () => 0);
    expect(state.players[0].job?.salary).toBe(80);
    expect(state.decks.collegeCareer.map((card) => card.id)).toEqual(["doc"]);
    expect(state.phase).toBe("awaitSpin");
    expect(state.current).toBe(0);
  });
});

describe("stops", () => {
  it("pays wedding gifts from every other player", () => {
    const track = boardFrom([
      space({ id: "wed", kind: "stop", stop: "married", next: ["end"], label: "Married" }),
      space({ id: "end", kind: "payday", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
    });
    const red = dispatch(playSpin(seat(track, decks), spins(1)), { type: "spin" }, spins(1));
    expect(red.players[0].married).toBe(true);
    expect(red.players[0].people).toBe(2);
    expect(red.players[0].babies).toBe(0);
    expect(red.players[0].cash).toBe(250);
    expect(red.players[1].cash).toBe(150);
    expect(red.phase).toBe("awaitSpin");

    const black = dispatch(playSpin(seat(track, decks), spins(1)), { type: "spin" }, spins(2));
    expect(black.players[0].cash).toBe(300);
    expect(black.players[1].cash).toBe(100);
    expect(black.lastSpin?.color).toBe("black");
  });

  it("uses the baby table and the six-peg car", () => {
    const stopTrack = boardFrom([
      space({ id: "babies", kind: "stop", stop: "baby", next: ["end"] }),
      space({ id: "end", kind: "payday", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
    });
    const cases: Array<[number, number]> = [
      [1, 0],
      [6, 1],
      [8, 2],
      [10, 3],
    ];
    for (const [spin, babies] of cases) {
      const state = dispatch(playSpin(seat(stopTrack, decks), spins(1)), { type: "spin" }, spins(spin));
      expect(state.players[0].babies).toBe(babies);
      expect(state.phase).toBe("awaitSpin");
    }

    const crowded = playSpin(
      seat(
        boardFrom([space({ id: "crowd", kind: "baby", babyCount: 10, next: [] })]),
        decks,
      ),
      spins(1),
    );
    expect(crowded.players[0].people).toBe(6);
    expect(crowded.players[0].babies).toBe(5);
  });

  it("lets night school replace a job or leave it", () => {
    const track = boardFrom([
      space({ id: "night", kind: "stop", stop: "nightSchool", next: ["end"], label: "Night school" }),
      space({ id: "end", kind: "payday", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
      collegeCareer: [{ id: "doc", kind: "collegeCareer", name: "Surgeon", salary: 90 }],
    });
    const offered = playSpin(seat(track, decks), spins(1));
    expect(offered.players[0].cash).toBe(100);
    expect(offered.phase).toBe("nightSchool");
    const kept = dispatch(offered, { type: "keepNightSchool", keep: true }, () => 0);
    expect(kept.players[0].job?.id).toBe("doc");
    expect(kept.players[0].job?.salary).toBe(90);
    expect(kept.phase).toBe("awaitSpin");

    const declined = dispatch(playSpin(seat(track, decks), spins(1)), {
      type: "keepNightSchool",
      keep: false,
    }, () => 0);
    expect(declined.players[0].job?.id).toBe("job-a");
    expect(declined.decks.collegeCareer.map((card) => card.id)).toEqual(["doc"]);
  });

  it("follows the branch chosen at a family stop", () => {
    const track = boardFrom([
      space({
        id: "fork",
        kind: "stop",
        stop: "family",
        next: ["kids", "skip"],
        label: "Family",
      }),
      space({ id: "kids", kind: "baby", babyCount: 1, next: ["end"], label: "Baby" }),
      space({ id: "skip", kind: "payday", next: ["end"], label: "Life" }),
      space({ id: "end", kind: "action", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
    });
    let family = playSpin(seat(track, decks), spins(1));
    expect(family.phase).toBe("chooseBranch");
    family = dispatch(family, { type: "chooseBranch", spaceId: "kids" }, () => 0);
    family = playSpin(family, spins(1));
    expect(family.players[0].spaceId).toBe("kids");
    expect(family.players[0].babies).toBe(1);

    let life = playSpin(seat(track, decks), spins(1));
    life = dispatch(life, { type: "chooseBranch", spaceId: "skip" }, () => 0);
    life = playSpin(life, spins(1));
    expect(life.players[0].spaceId).toBe("skip");
    expect(life.players[0].babies).toBe(0);
    expect(life.players[0].cash).toBe(340);
  });
});

describe("houses, loans, and spin to win", () => {
  it("buys one of two houses and sells it for the spun color", () => {
    const track = boardFrom([
      space({ id: "h1", kind: "house", next: ["h2"] }),
      space({ id: "h2", kind: "house", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
      house: [
        { id: "cottage", kind: "house", name: "Cottage", cost: 50, redSale: 80, blackSale: 30 },
        { id: "loft", kind: "house", name: "Loft", cost: 40, redSale: 10, blackSale: 70 },
      ],
    });
    let state = playSpin(seat(track, decks), spins(1));
    state = dispatch(state, { type: "houseDecision", decision: "buy" }, () => 0);
    state = dispatch(state, { type: "pickCard", cardId: "cottage" }, () => 0);
    expect(state.players[0].cash).toBe(150);
    expect(state.players[0].houses.map((card) => card.id)).toEqual(["cottage"]);
    expect(state.decks.house.map((card) => card.id)).toEqual(["loft"]);

    state = playSpin(state, spins(1));
    expect(state.players[1].spaceId).toBe("h1");
    state = dispatch(state, { type: "houseDecision", decision: "skip" }, () => 0);
    state = playSpin(state, spins(1));
    expect(state.players[0].spaceId).toBe("h2");
    state = dispatch(state, { type: "houseDecision", decision: "sell" }, () => 0);
    state = dispatch(state, { type: "pickHouseToSell", cardId: "cottage" }, () => 0);
    state = dispatch(state, { type: "spin" }, spins(1));
    expect(state.players[0].cash).toBe(230);
    expect(state.players[0].houses).toHaveLength(0);

    let black = playSpin(seat(track, decks), spins(1));
    black = dispatch(black, { type: "houseDecision", decision: "buy" }, () => 0);
    black = dispatch(black, { type: "pickCard", cardId: "cottage" }, () => 0);
    black = playSpin(black, spins(1));
    black = dispatch(black, { type: "houseDecision", decision: "skip" }, () => 0);
    black = playSpin(black, spins(1));
    black = dispatch(black, { type: "houseDecision", decision: "sell" }, () => 0);
    black = dispatch(black, { type: "pickHouseToSell", cardId: "cottage" }, () => 0);
    black = dispatch(black, { type: "spin" }, spins(2));
    expect(black.players[0].cash).toBe(180);
  });

  it("borrows in 50K loans and repays one for 60K", () => {
    const track = boardFrom([
      space({ id: "act", kind: "action", next: ["pay"] }),
      space({ id: "pay", kind: "payday", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
      action: [
        {
          id: "bill",
          kind: "action",
          name: "Big bill",
          text: "Pay the bank 210K.",
          effect: { type: "bankCharges", amount: 210 },
        },
        {
          id: "tip",
          kind: "action",
          name: "Tip",
          text: "The bank pays you 10K.",
          effect: { type: "bankPays", amount: 10 },
        },
      ],
    });
    const rng = spins(1, 1, 1, 1);
    let state = playSpin(seat(track, decks), rng);
    expect(state.players[0].loans).toBe(1);
    expect(state.players[0].cash).toBe(40);
    state = dispatch(state, { type: "acknowledge" }, rng);
    state = playSpin(state, rng);
    state = dispatch(state, { type: "acknowledge" }, rng);
    state = playSpin(state, rng);
    expect(state.players[0].cash).toBe(180);
    state = playSpin(state, rng);
    expect(state.phase).toBe("awaitSpin");
    expect(state.current).toBe(0);
    state = dispatch(state, { type: "repayLoan" }, rng);
    expect(state.players[0].loans).toBe(0);
    expect(state.players[0].cash).toBe(120);
  });

  it("rerolls Spin to Win until a covered number and pays each player once", () => {
    const track = boardFrom([space({ id: "win", kind: "spinToWin", next: [] })]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
    });
    const rng = spins(1, 1, 5);
    let state = playSpin(seat(track, decks), rng);
    expect(spinPrompt(state)?.playerId).toBe("p1");
    state = dispatch(state, { type: "pickSpinNumber", playerId: "p1", number: 5 }, rng);
    state = dispatch(state, { type: "pickSpinNumber", playerId: "p1", number: 5 }, rng);
    state = dispatch(state, { type: "pickSpinNumber", playerId: "p2", number: 3 }, rng);
    expect(state.lastSpin?.value).toBe(5);
    expect(state.players[0].cash).toBe(400);
    expect(state.players[1].cash).toBe(200);
    expect(state.phase).toBe("continue");

    const shared = spins(1, 5);
    let both = playSpin(seat(track, decks), shared);
    both = dispatch(both, { type: "pickSpinNumber", playerId: "p1", number: 5 }, shared);
    both = dispatch(both, { type: "pickSpinNumber", playerId: "p1", number: 5 }, shared);
    both = dispatch(both, { type: "pickSpinNumber", playerId: "p2", number: 5 }, shared);
    expect(both.players[0].cash).toBe(400);
    expect(both.players[1].cash).toBe(400);
  });
});

describe("retirement", () => {
  it("pays finish order and scores houses, cards, babies, and loans", () => {
    const track = boardFrom([
      space({ id: "babies", kind: "baby", babyCount: 2, next: ["act"] }),
      space({ id: "act", kind: "action", next: ["pet"] }),
      space({ id: "pet", kind: "pet", next: ["house"] }),
      space({ id: "house", kind: "house", next: ["retire"] }),
      space({ id: "retire", kind: "stop", stop: "retirement", next: [] }),
    ]);
    const decks = decksWith({
      career: [
        { id: "job-a", kind: "career", name: "Driver", salary: 40 },
        { id: "job-b", kind: "career", name: "Cook", salary: 20 },
      ],
      action: [
        {
          id: "bonus",
          kind: "action",
          name: "Bonus",
          text: "The bank pays you 20K.",
          effect: { type: "bankPays", amount: 20 },
        },
      ],
      pet: [
        {
          id: "vet",
          kind: "pet",
          name: "Vet",
          text: "Pay the bank 10K.",
          effect: { type: "bankCharges", amount: 10 },
        },
      ],
      house: [
        { id: "cottage", kind: "house", name: "Cottage", cost: 50, redSale: 80, blackSale: 30 },
        { id: "loft", kind: "house", name: "Loft", cost: 40, redSale: 10, blackSale: 70 },
      ],
    });
    const rng = spins(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);
    let state = seat(track, decks);
    const step = () => {
      state = playSpin(state, rng);
    };
    step();
    step();
    expect(state.players[0].babies).toBe(2);
    step();
    state = dispatch(state, { type: "acknowledge" }, rng);
    step();
    step();
    state = dispatch(state, { type: "acknowledge" }, rng);
    step();
    step();
    state = dispatch(state, { type: "houseDecision", decision: "buy" }, rng);
    state = dispatch(state, { type: "pickCard", cardId: "cottage" }, rng);
    step();
    state = dispatch(state, { type: "houseDecision", decision: "skip" }, rng);
    step();
    expect(state.phase).toBe("retireChoice");
    state = dispatch(state, { type: "chooseEstate", estate: "mansion" }, rng);
    expect(state.players[0].cash).toBe(560);
    step();
    state = dispatch(state, { type: "chooseEstate", estate: "acres" }, rng);
    expect(state.phase).toBe("needSpin");
    state = dispatch(state, { type: "spin" }, rng);
    expect(state.phase).toBe("gameOver");
    const ada = state.scores[0];
    const bea = state.scores[1];
    expect(ada.onHand).toBe(640);
    expect(ada.actions).toBe(100);
    expect(ada.pets).toBe(100);
    expect(ada.babies).toBe(100);
    expect(ada.loans).toBe(0);
    expect(ada.total).toBe(940);
    expect(bea.total).toBe(bea.onHand + 100);
    expect(state.winnerIds).toEqual(["p1"]);
  });
});

function auto(state: GameState, rng: Rng): GameState {
  switch (state.phase) {
    case "choosePath":
      return dispatch(
        state,
        { type: "choosePath", path: state.current === 0 ? "college" : "career" },
        rng,
      );
    case "pickCareer":
    case "pickHouse": {
      const card = state.offered[0];
      if (!card) throw new Error("nothing offered");
      return dispatch(state, { type: "pickCard", cardId: card.id }, rng);
    }
    case "awaitSpin":
    case "needSpin":
      return dispatch(state, { type: "spin" }, rng);
    case "moving":
      return dispatch(state, { type: "commitStep" }, rng);
    case "chooseBranch": {
      const calm = state.pendingBranches.find((id) => id.startsWith("life") || id.startsWith("safe"));
      return dispatch(state, { type: "chooseBranch", spaceId: calm ?? state.pendingBranches[0] }, rng);
    }
    case "nightSchool":
      return dispatch(state, { type: "keepNightSchool", keep: false }, rng);
    case "houseChoice":
      return dispatch(state, { type: "houseDecision", decision: "skip" }, rng);
    case "pickHouseSell": {
      const house = state.players[state.current].houses[0];
      if (!house) throw new Error("no house");
      return dispatch(state, { type: "pickHouseToSell", cardId: house.id }, rng);
    }
    case "spinToWinPick": {
      const prompt = spinPrompt(state);
      if (!prompt) throw new Error("no spin prompt");
      const number = prompt.have === 0 ? 3 : 7;
      return dispatch(state, { type: "pickSpinNumber", playerId: prompt.playerId, number }, rng);
    }
    case "continue":
      return dispatch(state, { type: "acknowledge" }, rng);
    case "retireChoice":
      return dispatch(state, { type: "chooseEstate", estate: "mansion" }, rng);
    case "gameOver":
      return state;
    default: {
      const exhaustive: never = state.phase;
      return exhaustive;
    }
  }
}

describe("full game", () => {
  it("plays the standard board through a winner", () => {
    let state = createGame(
      {
        players: [
          { name: "Ada", color: "red", petName: "Miso" },
          { name: "Bea", color: "blue", petName: "Dot" },
          { name: "Cal", color: "green", petName: "Nori" },
        ],
      },
      Math.random,
    );
    let guard = 0;
    while (state.phase !== "gameOver") {
      const before = `${state.phase}:${state.current}:${state.players[state.current]?.spaceId}`;
      state = auto(state, Math.random);
      if (++guard > 4000) {
        throw new Error(`stuck after ${before} -> ${state.phase} ${state.prompt}`);
      }
    }
    expect(state.scores).toHaveLength(3);
    expect(state.winnerIds.length).toBeGreaterThan(0);
    expect(state.players.every((player) => player.retired)).toBe(true);
  });
});
