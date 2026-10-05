import { useEffect, useRef, useState } from "react";
import {
  createGame,
  dispatch,
  formatK,
  spinPrompt,
  type GameState,
  type PegColor,
  type PlayerSetup,
  type Rng,
} from "@strife/rules";
import { mountBoard, type BoardApi, type BoardPoint } from "./boardView";

const COLORS: PegColor[] = ["red", "green", "blue", "purple"];

interface SeatDraft {
  name: string;
  color: PegColor;
  petName: string;
}

const STARTER: SeatDraft[] = [
  { name: "Ada", color: "red", petName: "Miso" },
  { name: "Bea", color: "blue", petName: "Dot" },
];

export function App() {
  const [seats, setSeats] = useState<SeatDraft[]>(STARTER);
  const [state, setState] = useState<GameState | null>(null);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [wheelValue, setWheelValue] = useState<number | null>(null);
  const [wheelTurns, setWheelTurns] = useState(0);
  const rng = useRef<Rng>(() => Math.random());
  const boardApi = useRef<BoardApi | null>(null);
  const boardHost = useRef<HTMLDivElement | null>(null);
  const stateRef = useRef<GameState | null>(null);
  stateRef.current = state;

  useEffect(() => {
    const parent = boardHost.current;
    if (!parent || !state) return;
    let dead = false;
    let api: BoardApi | null = null;
    void mountBoard(parent).then((created) => {
      if (dead) {
        created.destroy();
        return;
      }
      api = created;
      boardApi.current = created;
      if (stateRef.current) created.sync(stateRef.current);
    });
    return () => {
      dead = true;
      api?.destroy();
      boardApi.current = null;
    };
  }, [state === null]);

  useEffect(() => {
    if (!state || busy) return;
    boardApi.current?.sync(state);
  }, [state, busy]);

  if (!state) {
    return (
      <main className="setup">
        <section className="setup-card">
          <h1>Strife</h1>
          <p className="lede">
            Two to four players, one screen. Spin, follow the forks, and retire with the most money.
          </p>
          {seats.map((seat, index) => (
            <div className="player-row" key={seat.color}>
              <input
                aria-label={`Player ${index + 1} name`}
                value={seat.name}
                onChange={(event) => updateSeat(index, { name: event.target.value })}
              />
              <select
                aria-label={`Player ${index + 1} color`}
                value={seat.color}
                onChange={(event) => updateSeat(index, { color: event.target.value as PegColor })}
              >
                {COLORS.map((color) => (
                  <option key={color} value={color} disabled={seats.some((other, otherIndex) => otherIndex !== index && other.color === color)}>
                    {color}
                  </option>
                ))}
              </select>
              <input
                aria-label={`Player ${index + 1} pet`}
                value={seat.petName}
                onChange={(event) => updateSeat(index, { petName: event.target.value })}
              />
              <button className="secondary" type="button" onClick={() => removeSeat(index)} disabled={seats.length <= 2}>
                Remove
              </button>
            </div>
          ))}
          <div className="setup-actions">
            <button type="button" onClick={addSeat} disabled={seats.length >= 4}>
              Add player
            </button>
            <button type="button" onClick={start}>
              Start
            </button>
          </div>
        </section>
      </main>
    );
  }

  const player = state.players[state.current];
  const prompt = spinPrompt(state);

  function updateSeat(index: number, patch: Partial<SeatDraft>) {
    setSeats((current) => current.map((seat, seatIndex) => (seatIndex === index ? { ...seat, ...patch } : seat)));
  }

  function addSeat() {
    setSeats((current) => {
      const used = new Set(current.map((seat) => seat.color));
      const color = COLORS.find((entry) => !used.has(entry));
      if (!color) return current;
      return [...current, { name: `Player ${current.length + 1}`, color, petName: "Pip" }];
    });
  }

  function removeSeat(index: number) {
    setSeats((current) => (current.length <= 2 ? current : current.filter((_, seatIndex) => seatIndex !== index)));
  }

  function start() {
    const setups: PlayerSetup[] = seats.map((seat) => ({
      name: seat.name,
      color: seat.color,
      petName: seat.petName,
    }));
    try {
      setError(null);
      setState(createGame({ players: setups }, rng.current));
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Could not start.");
    }
  }

  function act(run: (current: GameState) => GameState) {
    if (!state || busy) return;
    try {
      setError(null);
      const next = run(state);
      if (next.lastSpin && next.lastSpin.value !== state.lastSpin?.value) revealSpin(next.lastSpin.value);
      else if (next.lastSpin && next.phase !== state.phase) revealSpin(next.lastSpin.value);
      setState(next);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "That move was refused.");
    }
  }

  function revealSpin(value: number) {
    setWheelValue(value);
    setWheelTurns((turns) => turns + 1);
  }

  async function spin() {
    if (!state || busy) return;
    setBusy(true);
    setError(null);
    setNote("The peg is moving.");
    try {
      const mover = state.players[state.current];
      let next = dispatch(state, { type: "spin" }, rng.current);
      if (next.lastSpin) revealSpin(next.lastSpin.value);
      const frames: BoardPoint[] = [];
      let guard = 0;
      while (next.phase === "moving") {
        next = dispatch(next, { type: "commitStep" }, rng.current);
        const moved = next.players.find((entry) => entry.id === mover.id);
        const space = moved?.spaceId ? next.board.spaces[moved.spaceId] : undefined;
        if (space) frames.push({ x: space.x, y: space.y });
        if (++guard > 20) break;
      }
      await boardApi.current?.animate(mover.id, frames);
      setState(next);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "The spin failed.");
    } finally {
      setBusy(false);
      setNote(null);
    }
  }

  return (
    <main className="table">
      <div className="board-host" ref={boardHost} />
      <aside className="sidebar">
        <div>
          <p className="brand">Strife</p>
          <p className="prompt">{note ?? state.prompt}</p>
        </div>
        <Wheel value={wheelValue} turns={wheelTurns} />
        {!busy && <Decisions state={state} promptId={prompt?.playerId ?? null} onAct={act} onSpin={() => void spin()} />}
        {error && <p className="error">{error}</p>}
        <section className="players">
          {state.players.map((entry) => {
            const score = state.scores.find((row) => row.playerId === entry.id);
            const cash = state.phase === "gameOver" && score ? score.total : entry.cash;
            return (
            <article className={entry.id === player.id && state.phase !== "gameOver" ? "player-card active" : "player-card"} key={entry.id}>
              <header>
                <h2>
                  {entry.name}
                  {entry.retired ? " · retired" : ""}
                </h2>
                <span className="cash">{formatK(cash)}</span>
              </header>
              <p className="meta">
                {entry.color} peg · pet {entry.petName}
                <br />
                {entry.job ? `${entry.job.name}, ${formatK(entry.job.salary)} salary` : "No job yet"}
                {entry.loans > 0 ? ` · ${entry.loans} ${entry.loans === 1 ? "loan" : "loans"}` : ""}
                <br />
                {entry.people} in the car · {entry.babies} {entry.babies === 1 ? "baby" : "babies"}
                {entry.married ? " · married" : ""}
                {entry.estate === "mansion" ? " · Millionaire Mansion" : ""}
                {entry.estate === "acres" ? " · Countryside Acres" : ""}
              </p>
              {entry.houses.length > 0 && <p className="meta">{entry.houses.map((house) => house.name).join(", ")}</p>}
              {entry.actions.length > 0 && (
                <p className="meta">Actions: {entry.actions.map((card) => card.name).join(", ")}</p>
              )}
              {entry.pets.length > 0 && <p className="meta">Pets: {entry.pets.map((card) => card.name).join(", ")}</p>}
            </article>
            );
          })}
        </section>
        {state.phase === "gameOver" && <Scoreboard state={state} onAgain={() => setState(null)} />}
        <ul className="log">
          {state.log.slice(-8).map((line, index) => (
            <li key={`${index}-${line}`}>{line}</li>
          ))}
        </ul>
      </aside>
    </main>
  );
}

function Wheel({ value, turns }: { value: number | null; turns: number }) {
  const angle = turns * 360 + (value ? (value - 1) * -36 : 0);
  return (
    <div className="wheel-wrap">
      <div className="wheel-stage">
        <div className="needle" />
        <div className="wheel" style={{ transform: `rotate(${angle}deg)` }}>
          <div className="wheel-hub">
            <span style={{ transform: `rotate(${-angle}deg)` }}>{value ?? "–"}</span>
          </div>
        {Array.from({ length: 10 }, (_, index) => {
          const number = index + 1;
          const radians = ((index * 36 - 90) * Math.PI) / 180;
          return (
            <span
              key={number}
              style={{
                position: "absolute",
                left: `${50 + Math.cos(radians) * 34}%`,
                top: `${50 + Math.sin(radians) * 34}%`,
                transform: "translate(-50%, -50%)",
                color: "#241c14",
                fontSize: "0.75rem",
                fontWeight: 600,
              }}
            >
              {number}
</span>
        );
        })}
        </div>
      </div>
      <p className="meta">Odd centers are red. Even centers are black. Drag the board to look around.</p>
    </div>
  );
}

function Decisions({
  state,
  promptId,
  onAct,
  onSpin,
}: {
  state: GameState;
  promptId: string | null;
  onAct: (run: (current: GameState) => GameState) => void;
  onSpin: () => void;
}) {
  const player = state.players[state.current];
  if (state.phase === "choosePath") {
    return (
      <div className="decisions">
        <button type="button" onClick={() => onAct((current) => dispatch(current, { type: "choosePath", path: "college" }, () => 0))}>
          College, pay 100K
        </button>
        <button type="button" onClick={() => onAct((current) => dispatch(current, { type: "choosePath", path: "career" }, () => 0))}>
          Career now
        </button>
      </div>
    );
  }
  if (state.phase === "pickCareer" || state.phase === "pickHouse" || state.phase === "nightSchool") {
    return (
      <div className="cards">
        {state.offered.map((card) => (
          <button
            className="choice"
            type="button"
            key={card.id}
            onClick={() =>
              onAct((current) =>
                state.phase === "nightSchool"
                  ? dispatch(current, { type: "keepNightSchool", keep: true }, () => 0)
                  : dispatch(current, { type: "pickCard", cardId: card.id }, () => 0),
              )
            }
          >
            <strong>{card.name}</strong>
            <span>
              {"salary" in card
                ? `${formatK(card.salary)} salary`
                : "cost" in card
                  ? `Buy ${formatK(card.cost)} · red ${formatK(card.redSale)} · black ${formatK(card.blackSale)}`
                  : card.text}
            </span>
          </button>
        ))}
        {state.phase === "nightSchool" && (
          <button className="secondary" type="button" onClick={() => onAct((current) => dispatch(current, { type: "keepNightSchool", keep: false }, () => 0))}>
            Keep {player.job?.name ?? "your job"}
          </button>
        )}
      </div>
    );
  }
  if (state.phase === "chooseBranch") {
    return (
      <div className="decisions">
        {state.pendingBranches.map((spaceId) => (
          <button key={spaceId} type="button" onClick={() => onAct((current) => dispatch(current, { type: "chooseBranch", spaceId }, () => 0))}>
            {branchName(spaceId)}
          </button>
        ))}
      </div>
    );
  }
  if (state.phase === "houseChoice") {
    return (
      <div className="decisions">
        <button type="button" onClick={() => onAct((current) => dispatch(current, { type: "houseDecision", decision: "buy" }, () => Math.random()))}>
          Buy
        </button>
        <button type="button" onClick={() => onAct((current) => dispatch(current, { type: "houseDecision", decision: "sell" }, () => 0))} disabled={player.houses.length === 0}>
          Sell
        </button>
        <button className="secondary" type="button" onClick={() => onAct((current) => dispatch(current, { type: "houseDecision", decision: "skip" }, () => 0))}>
          Pass
        </button>
      </div>
    );
  }
  if (state.phase === "pickHouseSell") {
    return (
      <div className="cards">
        {player.houses.map((house) => (
          <button className="choice" type="button" key={house.id} onClick={() => onAct((current) => dispatch(current, { type: "pickHouseToSell", cardId: house.id }, () => 0))}>
            <strong>{house.name}</strong>
            <span>
              Red {formatK(house.redSale)} · black {formatK(house.blackSale)}
            </span>
          </button>
        ))}
      </div>
    );
  }
  if (state.phase === "spinToWinPick" && promptId) {
    const prompted = state.players.find((entry) => entry.id === promptId);
    const picks = state.picks[promptId] ?? [];
    return (
      <div className="decisions">
        {Array.from({ length: 10 }, (_, index) => index + 1).map((number) => (
          <button key={number} type="button" onClick={() => onAct((current) => dispatch(current, { type: "pickSpinNumber", playerId: promptId, number }, () => Math.random()))}>
            {prompted?.name} · {number}
            {picks.includes(number) ? " · placed" : ""}
          </button>
        ))}
      </div>
    );
  }
  if (state.phase === "retireChoice") {
    return (
      <div className="decisions">
        <button type="button" onClick={() => onAct((current) => dispatch(current, { type: "chooseEstate", estate: "mansion" }, () => 0))}>
          Millionaire Mansion
        </button>
        <button type="button" onClick={() => onAct((current) => dispatch(current, { type: "chooseEstate", estate: "acres" }, () => 0))}>
          Countryside Acres
        </button>
      </div>
    );
  }
  if (state.phase === "continue") {
    return (
      <div className="decisions">
        {state.revealed && (
          <p className="prompt">
            <strong>{state.revealed.name}.</strong> {state.revealed.text}
          </p>
        )}
        <button type="button" onClick={() => onAct((current) => dispatch(current, { type: "acknowledge" }, () => 0))}>
          Continue
        </button>
      </div>
    );
  }
  if (state.phase === "awaitSpin" || state.phase === "needSpin") {
    return (
      <div className="decisions">
        <button type="button" onClick={onSpin}>
          Spin
        </button>
        {state.phase === "awaitSpin" && player.loans > 0 && (
          <button className="secondary" type="button" onClick={() => onAct((current) => dispatch(current, { type: "repayLoan" }, () => 0))} disabled={player.cash < 60}>
            Repay a loan, 60K
          </button>
        )}
      </div>
    );
  }
  return null;
}

function branchName(spaceId: string): string {
  if (spaceId.startsWith("family")) return "Family path";
  if (spaceId.startsWith("life")) return "Life path";
  if (spaceId.startsWith("risky")) return "Risky road";
  if (spaceId.startsWith("safe")) return "Safe route";
  return spaceId;
}

function Scoreboard({ state, onAgain }: { state: GameState; onAgain: () => void }) {
  return (
    <section className="scoreboard">
      <h2>{state.prompt}</h2>
      {state.scores.map((row) => (
        <article className="score-card" key={row.playerId}>
          <h3 className={state.winnerIds.includes(row.playerId) ? "winner" : undefined}>{row.name}</h3>
          <p className="meta">
            {formatK(row.onHand)} on hand
            <br />+ {formatK(row.actions)} actions · + {formatK(row.pets)} pets · + {formatK(row.babies)} babies
            <br />− {formatK(row.loans)} loans
            <br />
            <strong>{formatK(row.total)}</strong>
          </p>
        </article>
      ))}
      <div className="score-actions">
        <button type="button" onClick={onAgain}>
          New game
        </button>
      </div>
    </section>
  );
}
