export type Rng = () => number;

export type PegColor = "red" | "green" | "blue" | "purple";

export type SpaceKind =
  | "payday"
  | "action"
  | "pet"
  | "house"
  | "spinToWin"
  | "baby"
  | "stop";

export type StopKind =
  | "graduation"
  | "married"
  | "family"
  | "baby"
  | "nightSchool"
  | "risky"
  | "retirement";

export interface Space {
  id: string;
  kind: SpaceKind;
  stop?: StopKind;
  babyCount?: number;
  next: string[];
  x: number;
  y: number;
  label: string;
}

export interface Board {
  spaces: Record<string, Space>;
  entries: {
    college: string;
    career: string;
  };
}

export type SpinColor = "red" | "black";

export type MoneyEffect =
  | { type: "bankPays"; amount: number }
  | { type: "bankCharges"; amount: number }
  | { type: "eachOtherPaysYou"; amount: number }
  | { type: "youPayEach"; amount: number };

export interface CareerCard {
  id: string;
  kind: "career" | "collegeCareer";
  name: string;
  salary: number;
}

export interface HouseCard {
  id: string;
  kind: "house";
  name: string;
  cost: number;
  redSale: number;
  blackSale: number;
}

export interface KeepCard {
  id: string;
  kind: "action" | "pet";
  name: string;
  text: string;
  effect: MoneyEffect;
}

export type Card = CareerCard | HouseCard | KeepCard;

export interface Decks {
  career: CareerCard[];
  collegeCareer: CareerCard[];
  house: HouseCard[];
  action: KeepCard[];
  pet: KeepCard[];
}

export interface Player {
  id: string;
  name: string;
  color: PegColor;
  petName: string;
  cash: number;
  loans: number;
  job: CareerCard | null;
  path: "college" | "career" | null;
  spaceId: string | null;
  people: number;
  babies: number;
  married: boolean;
  actions: KeepCard[];
  pets: KeepCard[];
  houses: HouseCard[];
  retired: boolean;
  estate: "mansion" | "acres" | null;
  forcedNext: string | null;
}

export type Phase =
  | "choosePath"
  | "pickCareer"
  | "awaitSpin"
  | "moving"
  | "chooseBranch"
  | "needSpin"
  | "nightSchool"
  | "houseChoice"
  | "pickHouse"
  | "pickHouseSell"
  | "spinToWinPick"
  | "continue"
  | "retireChoice"
  | "gameOver";

export type SpinPurpose =
  | "move"
  | "married"
  | "baby"
  | "houseSale"
  | "spinToWin"
  | "finalHouse";

export type CareerPickReason = "setup" | "graduation";

export interface ScoreRow {
  playerId: string;
  name: string;
  onHand: number;
  actions: number;
  pets: number;
  babies: number;
  loans: number;
  total: number;
}

export interface GameState {
  players: Player[];
  current: number;
  phase: Phase;
  spinPurpose: SpinPurpose;
  board: Board;
  decks: Decks;
  discards: Decks;
  stepsLeft: number;
  lastSpin: { value: number; color: SpinColor } | null;
  offered: Card[];
  careerPick: CareerPickReason | null;
  pendingBranches: string[];
  selling: HouseCard | null;
  revealed: KeepCard | null;
  picks: Record<string, number[]>;
  spinWinners: string[];
  finalePlayer: number;
  prompt: string;
  log: string[];
  scores: ScoreRow[];
  winnerIds: string[];
}

export type Action =
  | { type: "choosePath"; path: "college" | "career" }
  | { type: "pickCard"; cardId: string }
  | { type: "spin" }
  | { type: "commitStep" }
  | { type: "chooseBranch"; spaceId: string }
  | { type: "keepNightSchool"; keep: boolean }
  | { type: "houseDecision"; decision: "buy" | "sell" | "skip" }
  | { type: "pickHouseToSell"; cardId: string }
  | { type: "pickSpinNumber"; playerId: string; number: number }
  | { type: "chooseEstate"; estate: "mansion" | "acres" }
  | { type: "acknowledge" }
  | { type: "repayLoan" };

export interface PlayerSetup {
  name: string;
  color: PegColor;
  petName: string;
}

export const CAR_CAPACITY = 6;
export const START_CASH = 200;
export const RETIRE_BONUS = [400, 300, 200, 100] as const;
