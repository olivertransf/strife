import type { Rng, SpinColor } from "./types";

/** Odd spinner numbers are red in the center. Even numbers are black. */
export function spinColor(value: number): SpinColor {
  return value % 2 === 1 ? "red" : "black";
}

export function rollSpinner(rng: Rng): number {
  return 1 + Math.floor(rng() * 10);
}

/** Baby STOP table: 1–3 none, 4–6 one, 7–8 twins, 9–10 triplets. */
export function babiesFromSpin(value: number): number {
  if (value <= 3) return 0;
  if (value <= 6) return 1;
  if (value <= 8) return 2;
  return 3;
}

export function formatK(amount: number): string {
  return `${amount}K`;
}
