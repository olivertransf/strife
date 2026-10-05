import { standardBoard } from "./board";
import { standardDecks } from "./decks";
import { babiesFromSpin, rollSpinner, spinColor } from "./spinner";
import type {
  Action,
  Board,
  Card,
  CareerCard,
  CareerPickReason,
  Decks,
  GameState,
  HouseCard,
  KeepCard,
  MoneyEffect,
  Player,
  PlayerSetup,
  Rng,
  Space,
  SpinColor,
} from "./types";
import { CAR_CAPACITY, RETIRE_BONUS, START_CASH } from "./types";

export interface CreateOptions {
  board?: Board;
  decks?: Decks;
  shuffle?: boolean;
}

const COLORS = new Set(["red", "green", "blue", "purple"]);

function fail(message: string): never {
  throw new Error(message);
}

function emptyDecks(): Decks {
  return { career: [], collegeCareer: [], house: [], action: [], pet: [] };
}

function shuffle<T>(items: T[], rng: Rng): T[] {
  const copy = [...items];
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swap = Math.floor(rng() * (index + 1));
    const current = copy[index];
    copy[index] = copy[swap];
    copy[swap] = current;
  }
  return copy;
}

function current(state: GameState): Player {
  const player = state.players[state.current];
  if (!player) fail("No current player.");
  return player;
}

function log(state: GameState, message: string) {
  state.log.push(message);
}

function charge(state: GameState, player: Player, amount: number, reason: string) {
  if (amount <= 0) return;
  if (player.cash < amount) {
    const need = amount - player.cash;
    const loans = Math.ceil(need / 50);
    player.loans += loans;
    player.cash += loans * 50;
    log(
      state,
      `${player.name} borrows ${loans * 50}K (${loans} ${loans === 1 ? "loan" : "loans"}).`,
    );
  }
  player.cash -= amount;
  log(state, `${player.name} pays ${amount}K${reason}.`);
}

function collect(state: GameState, player: Player, amount: number, reason: string) {
  if (amount === 0) return;
  player.cash += amount;
  log(state, `${player.name} collects ${amount}K${reason}.`);
}

function draw(state: GameState, key: keyof Decks, rng: Rng): Card | null {
  const deck = state.decks[key] as Card[];
  const discard = state.discards[key] as Card[];
  if (deck.length === 0) {
    if (discard.length === 0) return null;
    deck.push(...shuffle(discard.splice(0, discard.length), rng));
  }
  return deck.shift() ?? null;
}

function drawUpTo(state: GameState, key: keyof Decks, count: number, rng: Rng): Card[] {
  const cards: Card[] = [];
  for (let index = 0; index < count; index += 1) {
    const card = draw(state, key, rng);
    if (!card) break;
    cards.push(card);
  }
  return cards;
}

function isCareer(card: Card): card is CareerCard {
  return card.kind === "career" || card.kind === "collegeCareer";
}

function isHouse(card: Card): card is HouseCard {
  return card.kind === "house";
}

function isKeep(card: Card): card is KeepCard {
  return card.kind === "action" || card.kind === "pet";
}

function returnToBottom(state: GameState, card: Card) {
  if (isCareer(card)) {
    const pile = card.kind === "career" ? state.decks.career : state.decks.collegeCareer;
    pile.push(card);
    return;
  }
  if (isHouse(card)) {
    state.decks.house.push(card);
    return;
  }
  const pile = card.kind === "action" ? state.decks.action : state.decks.pet;
  pile.push(card);
}

export function createGame(
  config: { players: PlayerSetup[] },
  rng: Rng,
  options: CreateOptions = {},
): GameState {
  if (config.players.length < 2 || config.players.length > 4) {
    fail("Strife seats 2 to 4 players.");
  }
  const seen = new Set<string>();
  for (const setup of config.players) {
    if (!COLORS.has(setup.color)) fail(`Unknown color ${setup.color}.`);
    if (seen.has(setup.color)) fail("Each player needs a different car color.");
    seen.add(setup.color);
  }

  const decks = structuredClone(options.decks ?? standardDecks());
  if (options.shuffle !== false) {
    decks.career = shuffle(decks.career, rng);
    decks.collegeCareer = shuffle(decks.collegeCareer, rng);
    decks.house = shuffle(decks.house, rng);
    decks.action = shuffle(decks.action, rng);
    decks.pet = shuffle(decks.pet, rng);
  }

  const players: Player[] = config.players.map((setup, index) => ({
    id: `p${index + 1}`,
    name: setup.name.trim() || `Player ${index + 1}`,
    color: setup.color,
    petName: setup.petName.trim() || "Pip",
    cash: START_CASH,
    loans: 0,
    job: null,
    path: null,
    spaceId: null,
    people: 1,
    babies: 0,
    married: false,
    actions: [],
    pets: [],
    houses: [],
    retired: false,
    estate: null,
    forcedNext: null,
  }));

  const state: GameState = {
    players,
    current: 0,
    phase: "choosePath",
    spinPurpose: "move",
    board: structuredClone(options.board ?? standardBoard()),
    decks,
    discards: emptyDecks(),
    stepsLeft: 0,
    lastSpin: null,
    offered: [],
    careerPick: null,
    pendingBranches: [],
    selling: null,
    revealed: null,
    picks: {},
    spinWinners: [],
    finalePlayer: 0,
    prompt: "",
    log: [],
    scores: [],
    winnerIds: [],
  };
  state.prompt = `${players[0].name}, college or career?`;
  log(state, "Everyone starts with 200K, one peg, and a pet.");
  return state;
}

export function dispatch(state: GameState, action: Action, rng: Rng): GameState {
  const next = structuredClone(state);
  apply(next, action, rng);
  return next;
}

function apply(state: GameState, action: Action, rng: Rng) {
  switch (action.type) {
    case "choosePath":
      choosePath(state, action.path, rng);
      return;
    case "pickCard":
      pickCard(state, action.cardId);
      return;
    case "spin":
      onSpin(state, rng);
      return;
    case "commitStep":
      commitStep(state, rng);
      return;
    case "chooseBranch":
      chooseBranch(state, action.spaceId);
      return;
    case "keepNightSchool":
      keepNightSchool(state, action.keep);
      return;
    case "houseDecision":
      houseDecision(state, action.decision, rng);
      return;
    case "pickHouseToSell":
      pickHouseToSell(state, action.cardId);
      return;
    case "pickSpinNumber":
      pickSpinNumber(state, action.playerId, action.number, rng);
      return;
    case "chooseEstate":
      chooseEstate(state, action.estate);
      return;
    case "acknowledge":
      acknowledge(state);
      return;
    case "repayLoan":
      repayLoan(state);
      return;
    default: {
      const exhaustive: never = action;
      return exhaustive;
    }
  }
}

function choosePath(state: GameState, path: "college" | "career", rng: Rng) {
  if (state.phase !== "choosePath") fail("Nobody is choosing a path.");
  const player = current(state);
  player.path = path;
  if (path === "college") {
    charge(state, player, 100, " in tuition");
    log(state, `${player.name} heads to college.`);
    advanceSetup(state);
    return;
  }
  log(state, `${player.name} starts a career.`);
  offerCareers(state, "career", "setup", rng);
}

function offerCareers(
  state: GameState,
  key: "career" | "collegeCareer",
  reason: CareerPickReason,
  rng: Rng,
) {
  const cards = drawUpTo(state, key, 2, rng).filter(isCareer);
  if (cards.length === 0) {
    log(state, "The career deck is empty.");
    if (reason === "setup") advanceSetup(state);
    else spinAgain(state);
    return;
  }
  state.offered = cards;
  state.careerPick = reason;
  state.phase = "pickCareer";
  state.prompt = `${current(state).name}, choose one of ${cards.length === 1 ? "this career" : "these two careers"}.`;
}

function pickCard(state: GameState, cardId: string) {
  if (state.phase === "pickCareer") {
    pickCareer(state, cardId);
    return;
  }
  if (state.phase === "pickHouse") {
    buyHouse(state, cardId);
    return;
  }
  fail("There is no card to choose.");
}

function pickCareer(state: GameState, cardId: string) {
  const chosen = state.offered.find((card) => card.id === cardId);
  if (!chosen || !isCareer(chosen)) fail("That career is not on offer.");
  const player = current(state);
  if (player.job) returnToBottom(state, player.job);
  player.job = chosen;
  for (const other of state.offered) {
    if (other.id !== chosen.id) returnToBottom(state, other);
  }
  state.offered = [];
  log(state, `${player.name} becomes a ${chosen.name} (${chosen.salary}K salary).`);
  const reason = state.careerPick;
  state.careerPick = null;
  if (reason === "graduation") spinAgain(state);
  else advanceSetup(state);
}

function advanceSetup(state: GameState) {
  if (state.current < state.players.length - 1) {
    state.current += 1;
    state.phase = "choosePath";
    state.prompt = `${current(state).name}, college or career?`;
    return;
  }
  state.current = 0;
  state.phase = "awaitSpin";
  state.spinPurpose = "move";
  state.prompt = `${current(state).name}, spin.`;
}

function onSpin(state: GameState, rng: Rng) {
  if (state.phase !== "awaitSpin" && state.phase !== "needSpin") fail("Not ready to spin.");
  const value = rollSpinner(rng);
  const color = spinColor(value);
  state.lastSpin = { value, color };
  switch (state.spinPurpose) {
    case "move":
      state.stepsLeft = value;
      state.phase = "moving";
      state.prompt = `${current(state).name} spins ${value}.`;
      log(state, `${current(state).name} spins ${value}.`);
      return;
    case "married":
      payGifts(state, color);
      spinAgain(state);
      return;
    case "baby":
      addBabies(state, current(state), babiesFromSpin(value));
      spinAgain(state);
      return;
    case "houseSale":
      sellHouse(state, color);
      endTurn(state);
      return;
    case "finalHouse":
      sellFinalHouse(state, color);
      return;
    case "spinToWin":
      fail("Spin to Win resolves when the tokens are down.");
      return;
    default: {
      const exhaustive: never = state.spinPurpose;
      return exhaustive;
    }
  }
}

function destinations(state: GameState, player: Player): string[] {
  if (player.spaceId === null) {
    if (player.path === "college") return [state.board.entries.college];
    if (player.path === "career") return [state.board.entries.career];
    fail(`${player.name} has not chosen a path.`);
  }
  return state.board.spaces[player.spaceId]?.next ?? [];
}

function commitStep(state: GameState, rng: Rng) {
  if (state.phase !== "moving") fail("The car is not moving.");
  if (state.stepsLeft <= 0) fail("No steps left.");
  const player = current(state);
  let destination: string;
  if (player.forcedNext) {
    destination = player.forcedNext;
    player.forcedNext = null;
  } else {
    const options = destinations(state, player);
    if (options.length === 0) {
      state.stepsLeft = 0;
      endTurn(state);
      return;
    }
    if (options.length > 1) {
      state.phase = "chooseBranch";
      state.pendingBranches = options;
      state.prompt = `${player.name}, choose a path.`;
      return;
    }
    destination = options[0];
  }

  const space = state.board.spaces[destination];
  if (!space) fail(`Missing space ${destination}.`);
  player.spaceId = destination;
  state.stepsLeft -= 1;

  if (space.kind === "stop" && space.stop) {
    state.stepsLeft = 0;
    resolveStop(state, space, rng);
    return;
  }

  const landing = state.stepsLeft === 0;
  if (space.kind === "payday") {
    const salary = player.job?.salary ?? 0;
    collect(state, player, salary, landing ? " in salary" : " for passing payday");
    if (landing) collect(state, player, 100, " as a payday bonus");
  }
  if (landing) resolveLanding(state, space, rng);
}

function resolveStop(state: GameState, space: Space, rng: Rng) {
  const player = current(state);
  const stop = space.stop;
  if (!stop) fail(`${space.id} is not a stop.`);
  switch (stop) {
    case "graduation":
      log(state, `${player.name} reaches graduation.`);
      offerCareers(state, "collegeCareer", "graduation", rng);
      return;
    case "married":
      if (!player.married && player.people < CAR_CAPACITY) {
        player.people += 1;
        player.married = true;
        log(state, `${player.name} gets married. A spouse peg joins the car.`);
      }
      state.phase = "needSpin";
      state.spinPurpose = "married";
      state.prompt = `${player.name}, spin for wedding gifts. Red is 50K from each player. Black is 100K.`;
      return;
    case "family":
      state.phase = "chooseBranch";
      state.pendingBranches = space.next;
      state.prompt = `${player.name}, raise a family or stay on the life path. Then spin again.`;
      return;
    case "baby":
      state.phase = "needSpin";
      state.spinPurpose = "baby";
      state.prompt = `${player.name}, spin for babies. 1–3 none, 4–6 one, 7–8 twins, 9–10 triplets.`;
      return;
    case "nightSchool":
      charge(state, player, 100, " for night school");
      {
        const card = draw(state, "collegeCareer", rng);
        if (!card || !isCareer(card)) {
          log(state, "No college careers are left.");
          spinAgain(state);
          return;
        }
        state.offered = [card];
        state.phase = "nightSchool";
        state.prompt = `${player.name}, night school offers ${card.name} (${card.salary}K). Keep it, or keep your current job?`;
      }
      return;
    case "risky":
      state.phase = "chooseBranch";
      state.pendingBranches = space.next;
      state.prompt = `${player.name}, take the risky road or the safe route. Then spin again.`;
      return;
    case "retirement":
      state.phase = "retireChoice";
      state.prompt = `${player.name}, retire to Millionaire Mansion or Countryside Acres.`;
      return;
    default: {
      const exhaustive: never = stop;
      return exhaustive;
    }
  }
}

function resolveLanding(state: GameState, space: Space, rng: Rng) {
  switch (space.kind) {
    case "payday":
      endTurn(state);
      return;
    case "action":
    case "pet":
      drawKeep(state, space.kind, rng);
      return;
    case "house":
      state.phase = "houseChoice";
      state.prompt = `${current(state).name}, buy a house, sell one, or pass.`;
      return;
    case "spinToWin":
      state.phase = "spinToWinPick";
      state.picks = {};
      state.spinWinners = [];
      state.prompt = `${current(state).name} landed on Spin to Win. Everyone places a token. The landing player places two.`;
      return;
    case "baby":
      addBabies(state, current(state), space.babyCount ?? 1);
      endTurn(state);
      return;
    case "stop":
      return;
    default: {
      const exhaustive: never = space.kind;
      return exhaustive;
    }
  }
}

function drawKeep(state: GameState, kind: "action" | "pet", rng: Rng) {
  const card = draw(state, kind, rng);
  const player = current(state);
  if (!card || !isKeep(card)) {
    log(state, `No ${kind} cards are left.`);
    endTurn(state);
    return;
  }
  if (kind === "action") player.actions.push(card);
  else player.pets.push(card);
  applyEffect(state, player, card.effect, card.name);
  state.revealed = card;
  state.phase = "continue";
  state.prompt = `${player.name} draws ${card.name}. ${card.text}`;
}

function applyEffect(state: GameState, player: Player, effect: MoneyEffect, label: string) {
  switch (effect.type) {
    case "bankPays":
      collect(state, player, effect.amount, ` from ${label}`);
      return;
    case "bankCharges":
      charge(state, player, effect.amount, ` for ${label}`);
      return;
    case "eachOtherPaysYou":
      for (const other of state.players) {
        if (other.id === player.id) continue;
        charge(state, other, effect.amount, ` for ${label}`);
        player.cash += effect.amount;
      }
      log(state, `${player.name} collects ${effect.amount}K from each player.`);
      return;
    case "youPayEach":
      for (const other of state.players) {
        if (other.id === player.id) continue;
        charge(state, player, effect.amount, ` to ${other.name}`);
        other.cash += effect.amount;
      }
      return;
    default: {
      const exhaustive: never = effect;
      return exhaustive;
    }
  }
}

function addBabies(state: GameState, player: Player, count: number) {
  const room = CAR_CAPACITY - player.people;
  const added = Math.max(0, Math.min(count, room));
  player.people += added;
  player.babies += added;
  if (count === 0) {
    log(state, `${player.name} has no new babies.`);
    return;
  }
  if (added === 0) {
    log(state, `${player.name}'s car is full. No baby pegs fit.`);
    return;
  }
  if (added < count) {
    log(state, `${player.name} adds ${added} ${added === 1 ? "baby" : "babies"}. The car is full.`);
    return;
  }
  log(state, `${player.name} adds ${added} ${added === 1 ? "baby" : "babies"}.`);
}

function payGifts(state: GameState, color: SpinColor) {
  const amount = color === "red" ? 50 : 100;
  const player = current(state);
  for (const other of state.players) {
    if (other.id === player.id) continue;
    charge(state, other, amount, " as a wedding gift");
    player.cash += amount;
  }
  log(state, `${player.name} collects ${amount}K from each player (${color}).`);
}

function chooseBranch(state: GameState, spaceId: string) {
  if (state.phase !== "chooseBranch") fail("There is no fork to choose.");
  if (!state.pendingBranches.includes(spaceId)) fail("That path is not open.");
  const player = current(state);
  player.forcedNext = spaceId;
  state.pendingBranches = [];
  const label = state.board.spaces[spaceId]?.label ?? spaceId;
  log(state, `${player.name} takes ${label}.`);
  if (state.stepsLeft > 0) {
    state.phase = "moving";
    state.prompt = `${player.name} continues.`;
    return;
  }
  spinAgain(state);
}

function keepNightSchool(state: GameState, keep: boolean) {
  if (state.phase !== "nightSchool") fail("Night school is not in session.");
  const offered = state.offered[0];
  if (!offered || !isCareer(offered)) fail("No college career is on offer.");
  const player = current(state);
  if (keep) {
    if (player.job) returnToBottom(state, player.job);
    player.job = offered;
    log(state, `${player.name} takes ${offered.name} (${offered.salary}K).`);
  } else {
    returnToBottom(state, offered);
    log(state, `${player.name} keeps ${player.job?.name ?? "no job"}.`);
  }
  state.offered = [];
  spinAgain(state);
}

function houseDecision(state: GameState, decision: "buy" | "sell" | "skip", rng: Rng) {
  if (state.phase !== "houseChoice") fail("This is not a house space.");
  const player = current(state);
  if (decision === "skip") {
    log(state, `${player.name} passes on housing.`);
    endTurn(state);
    return;
  }
  if (decision === "sell") {
    if (player.houses.length === 0) fail("You have no house to sell.");
    state.phase = "pickHouseSell";
    state.prompt = `${player.name}, choose a house to sell.`;
    return;
  }
  const cards = drawUpTo(state, "house", 2, rng);
  if (cards.length === 0) {
    log(state, "No houses are left to buy.");
    endTurn(state);
    return;
  }
  state.offered = cards;
  state.phase = "pickHouse";
  state.prompt = `${player.name}, choose a house to buy.`;
}

function buyHouse(state: GameState, cardId: string) {
  const chosen = state.offered.find((card) => card.id === cardId);
  if (!chosen || !isHouse(chosen)) fail("That house is not on offer.");
  const player = current(state);
  charge(state, player, chosen.cost, ` for ${chosen.name}`);
  player.houses.push(chosen);
  for (const other of state.offered) {
    if (other.id !== chosen.id) returnToBottom(state, other);
  }
  state.offered = [];
  log(state, `${player.name} buys ${chosen.name}.`);
  endTurn(state);
}

function pickHouseToSell(state: GameState, cardId: string) {
  if (state.phase !== "pickHouseSell") fail("No house is being sold.");
  const player = current(state);
  const house = player.houses.find((card) => card.id === cardId);
  if (!house) fail("That house is not yours.");
  player.houses = player.houses.filter((card) => card.id !== house.id);
  state.selling = house;
  state.phase = "needSpin";
  state.spinPurpose = "houseSale";
  state.prompt = `Spin to sell ${house.name}. Red ${house.redSale}K, black ${house.blackSale}K.`;
}

function sellHouse(state: GameState, color: SpinColor) {
  const house = state.selling;
  if (!house) fail("No house is up for sale.");
  const amount = color === "red" ? house.redSale : house.blackSale;
  collect(state, current(state), amount, ` selling ${house.name} (${color})`);
  state.decks.house.push(house);
  state.selling = null;
}

function spinAgain(state: GameState) {
  state.phase = "awaitSpin";
  state.spinPurpose = "move";
  state.stepsLeft = 0;
  state.prompt = `${current(state).name}, spin again.`;
}

export function spinPrompt(
  state: GameState,
): { playerId: string; need: number; have: number } | null {
  if (state.phase !== "spinToWinPick") return null;
  const lander = state.players[state.current]?.id;
  for (let offset = 0; offset < state.players.length; offset += 1) {
    const player = state.players[(state.current + offset) % state.players.length];
    const need = player.id === lander ? 2 : 1;
    const have = state.picks[player.id]?.length ?? 0;
    if (have < need) return { playerId: player.id, need, have };
  }
  return null;
}

function pickSpinNumber(state: GameState, playerId: string, number: number, rng: Rng) {
  if (state.phase !== "spinToWinPick") fail("Spin to Win is not waiting for tokens.");
  if (number < 1 || number > 10) fail("Pick a number from 1 to 10.");
  const prompt = spinPrompt(state);
  if (!prompt || prompt.playerId !== playerId) fail("It is not that player's token.");
  const existing = state.picks[playerId] ?? [];
  state.picks[playerId] = [...existing, number];
  if (spinPrompt(state)) {
    const next = spinPrompt(state);
    const name = state.players.find((player) => player.id === next?.playerId)?.name ?? "Next";
    state.prompt = `${name}, place ${next && next.need - next.have === 2 ? "two tokens" : "a token"}.`;
    return;
  }
  resolveSpinToWin(state, rng);
}

function resolveSpinToWin(state: GameState, rng: Rng) {
  const covered = new Set(Object.values(state.picks).flat());
  let value = 1;
  for (let attempt = 0; attempt < 40; attempt += 1) {
    value = rollSpinner(rng);
    if (covered.has(value)) break;
    if (attempt === 39) fail("The wheel never hit a token.");
  }
  state.lastSpin = { value, color: spinColor(value) };
  const winners = state.players.filter((player) => (state.picks[player.id] ?? []).includes(value));
  for (const winner of winners) collect(state, winner, 200, " from Spin to Win");
  state.spinWinners = winners.map((player) => player.id);
  state.phase = "continue";
  const names = winners.map((player) => player.name).join(" and ");
  state.revealed = null;
  state.prompt = `The wheel hits ${value}. ${names} collect 200K.`;
  log(state, state.prompt);
}

function chooseEstate(state: GameState, estate: "mansion" | "acres") {
  if (state.phase !== "retireChoice") fail("This is not retirement.");
  const player = current(state);
  const order = state.players.filter((entry) => entry.retired).length;
  const bonus = RETIRE_BONUS[Math.min(order, RETIRE_BONUS.length - 1)];
  player.retired = true;
  player.estate = estate;
  player.cash += bonus;
  const place = estate === "mansion" ? "Millionaire Mansion" : "Countryside Acres";
  log(state, `${player.name} retires to ${place} and collects ${bonus}K.`);
  if (state.players.every((entry) => entry.retired)) beginFinale(state);
  else endTurn(state);
}

function beginFinale(state: GameState) {
  state.finalePlayer = 0;
  log(state, "Everyone has retired. Houses are sold, then wealth is counted.");
  advanceFinale(state);
}

function advanceFinale(state: GameState) {
  while (state.finalePlayer < state.players.length) {
    const player = state.players[state.finalePlayer];
    if (player.houses.length > 0) {
      state.current = state.finalePlayer;
      state.phase = "needSpin";
      state.spinPurpose = "finalHouse";
      state.prompt = `${player.name}, spin to sell ${player.houses[0].name}.`;
      return;
    }
    state.finalePlayer += 1;
  }
  score(state);
}

function sellFinalHouse(state: GameState, color: SpinColor) {
  const player = state.players[state.finalePlayer];
  const house = player.houses.shift();
  if (!house) fail("That player has no house to sell.");
  const amount = color === "red" ? house.redSale : house.blackSale;
  collect(state, player, amount, ` selling ${house.name} at the end (${color})`);
  state.decks.house.push(house);
  advanceFinale(state);
}

function score(state: GameState) {
  state.scores = state.players.map((player) => {
    const actions = player.actions.length * 100;
    const pets = player.pets.length * 100;
    const babies = player.babies * 50;
    const loans = player.loans * 60;
    const onHand = player.cash;
    return {
      playerId: player.id,
      name: player.name,
      onHand,
      actions,
      pets,
      babies,
      loans,
      total: onHand + actions + pets + babies - loans,
    };
  });
  const best = Math.max(...state.scores.map((row) => row.total));
  state.winnerIds = state.scores.filter((row) => row.total === best).map((row) => row.playerId);
  state.phase = "gameOver";
  const names = state.scores
    .filter((row) => state.winnerIds.includes(row.playerId))
    .map((row) => row.name)
    .join(" and ");
  state.prompt = `${names} ${state.winnerIds.length === 1 ? "wins" : "tie"} with ${best}K.`;
  log(state, state.prompt);
}

function acknowledge(state: GameState) {
  if (state.phase !== "continue") fail("Nothing to continue.");
  state.revealed = null;
  endTurn(state);
}

function repayLoan(state: GameState) {
  if (state.phase !== "awaitSpin") fail("Repay a loan before you spin.");
  const player = current(state);
  if (player.loans <= 0) fail("No loans to repay.");
  if (player.cash < 60) fail("Repaying a loan costs 60K.");
  player.cash -= 60;
  player.loans -= 1;
  log(state, `${player.name} repays a loan for 60K.`);
}

function endTurn(state: GameState) {
  state.stepsLeft = 0;
  state.offered = [];
  if (state.players.every((player) => player.retired)) {
    beginFinale(state);
    return;
  }
  for (let offset = 1; offset <= state.players.length; offset += 1) {
    const index = (state.current + offset) % state.players.length;
    if (!state.players[index].retired) {
      state.current = index;
      state.phase = "awaitSpin";
      state.spinPurpose = "move";
      state.prompt = `${current(state).name}, spin.`;
      return;
    }
  }
  beginFinale(state);
}
