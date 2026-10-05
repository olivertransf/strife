import type { Board, Space, SpaceKind, StopKind } from "./types";

const CELL = 150;

function at(col: number, row: number): { x: number; y: number } {
  return { x: 90 + col * CELL, y: 90 + row * CELL };
}

interface Draft {
  id: string;
  kind: SpaceKind;
  next: string[];
  col: number;
  row: number;
  label: string;
  stop?: StopKind;
  babyCount?: number;
}

function node(
  id: string,
  kind: SpaceKind,
  col: number,
  row: number,
  label: string,
  extra: { stop?: StopKind; babyCount?: number } = {},
): Draft {
  return { id, kind, next: [], col, row, label, ...extra };
}

function chain(nodes: Draft[]): void {
  for (let index = 0; index < nodes.length - 1; index += 1) {
    nodes[index].next = [nodes[index + 1].id];
  }
}

export function standardBoard(): Board {
  const college = [
    node("college-1", "action", 0, 0, "Act"),
    node("college-2", "pet", 1, 0, "Pet"),
    node("college-3", "action", 2, 0, "Act"),
    node("graduation", "stop", 3, 0, "Graduation", { stop: "graduation" }),
  ];
  const career = [
    node("career-1", "action", 0, 2, "Act"),
    node("career-2", "payday", 1, 2, "Pay"),
    node("career-3", "action", 2, 2, "Act"),
  ];
  const opening = [
    node("m1", "payday", 4, 1, "Pay"),
    node("m2", "action", 5, 1, "Act"),
    node("m3", "house", 6, 1, "House"),
    node("m4", "payday", 7, 1, "Pay"),
    node("m5", "pet", 8, 1, "Pet"),
    node("m6", "spinToWin", 9, 1, "Win"),
    node("m7", "payday", 10, 1, "Pay"),
    node("married", "stop", 11, 1, "Married", { stop: "married" }),
  ];
  const towardFamily = [
    node("m8", "payday", 11, 3, "Pay"),
    node("m9", "action", 10, 3, "Act"),
    node("m10", "house", 9, 3, "House"),
    node("family", "stop", 8, 3, "Family", { stop: "family" }),
  ];
  const familyPath = [
    node("family-1", "baby", 8, 0, "1", { babyCount: 1 }),
    node("family-2", "baby", 7, 0, "2", { babyCount: 2 }),
    node("family-baby", "stop", 6, 0, "Babies", { stop: "baby" }),
    node("family-3", "payday", 5, 0, "Pay"),
  ];
  const lifePath = [
    node("life-1", "action", 8, 4, "Act"),
    node("life-2", "payday", 7, 4, "Pay"),
  ];
  const afterFamily = [
    node("m11", "payday", 4, 5, "Pay"),
    node("m12", "action", 5, 5, "Act"),
    node("m13", "pet", 6, 5, "Pet"),
    node("night", "stop", 7, 5, "Night school", { stop: "nightSchool" }),
  ];
  const towardRisky = [
    node("m14", "payday", 9, 6, "Pay"),
    node("m15", "spinToWin", 10, 6, "Win"),
    node("risky", "stop", 11, 6, "Risky", { stop: "risky" }),
  ];
  const riskyPath = [
    node("risky-1", "action", 11, 7, "Act"),
    node("risky-2", "spinToWin", 10, 7, "Win"),
    node("risky-3", "payday", 9, 7, "Pay"),
  ];
  const safePath = [
    node("safe-1", "payday", 11, 5, "Pay"),
    node("safe-2", "action", 10, 5, "Act"),
  ];
  const ending = [
    node("m16", "house", 7, 7, "House"),
    node("m17", "payday", 6, 7, "Pay"),
    node("m18", "action", 5, 7, "Act"),
    node("m19", "pet", 4, 7, "Pet"),
    node("retirement", "stop", 2, 7, "Retirement", { stop: "retirement" }),
  ];

  chain(college);
  chain(career);
  chain(opening);
  chain(towardFamily);
  chain(familyPath);
  chain(lifePath);
  chain(afterFamily);
  chain(towardRisky);
  chain(riskyPath);
  chain(safePath);
  chain(ending);

  college[3].next = ["m1"];
  career[2].next = ["m1"];
  opening[7].next = ["m8"];
  towardFamily[3].next = ["family-1", "life-1"];
  familyPath[3].next = ["m11"];
  lifePath[1].next = ["m11"];
  afterFamily[3].next = ["m14"];
  towardRisky[2].next = ["risky-1", "safe-1"];
  riskyPath[2].next = ["m16"];
  safePath[1].next = ["m16"];
  ending[4].next = [];

  const drafts = [
    ...college,
    ...career,
    ...opening,
    ...towardFamily,
    ...familyPath,
    ...lifePath,
    ...afterFamily,
    ...towardRisky,
    ...riskyPath,
    ...safePath,
    ...ending,
  ];
  const spaces: Record<string, Space> = {};
  for (const draft of drafts) {
    const point = at(draft.col, draft.row);
    spaces[draft.id] = {
      id: draft.id,
      kind: draft.kind,
      stop: draft.stop,
      babyCount: draft.babyCount,
      next: draft.next,
      x: point.x,
      y: point.y,
      label: draft.label,
    };
  }

  return {
    spaces,
    entries: { college: "college-1", career: "career-1" },
  };
}

export const BOARD_BOUNDS = { width: 1980, height: 1320 };

export function boardProblems(board: Board): string[] {
  const problems: string[] = [];
  const ids = new Set(Object.keys(board.spaces));
  for (const entry of [board.entries.college, board.entries.career]) {
    if (!ids.has(entry)) problems.push(`Missing entry ${entry}`);
  }
  for (const space of Object.values(board.spaces)) {
    for (const next of space.next) {
      if (!ids.has(next)) problems.push(`${space.id} points at missing ${next}`);
    }
    if (space.kind === "stop" && !space.stop) problems.push(`${space.id} is a stop with no kind`);
    if (space.kind === "baby" && space.stop !== "baby" && (space.babyCount ?? 0) < 1) {
      problems.push(`${space.id} baby space has no count`);
    }
  }
  for (const start of [board.entries.college, board.entries.career]) {
    const seen = new Set<string>();
    const queue = [start];
    while (queue.length > 0) {
      const id = queue.shift();
      if (!id || seen.has(id)) continue;
      seen.add(id);
      for (const next of board.spaces[id]?.next ?? []) queue.push(next);
    }
    if (!seen.has("retirement")) problems.push(`${start} cannot reach retirement`);
  }
  return problems;
}
