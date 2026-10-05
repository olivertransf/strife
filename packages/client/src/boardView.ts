import Phaser from "phaser";
import { BOARD_BOUNDS } from "@strife/rules";
import type { GameState, PegColor, Space } from "@strife/rules";

type SpaceKind = Space["kind"];

export interface BoardPoint {
  x: number;
  y: number;
}

export interface BoardApi {
  sync: (state: GameState) => void;
  animate: (playerId: string, frames: BoardPoint[]) => Promise<void>;
  destroy: () => void;
}

const FILL: Record<SpaceKind, number> = {
  payday: 0x3f9d62,
  action: 0xe2b14a,
  pet: 0xef8b3c,
  house: 0x8a5a3a,
  spinToWin: 0x6d5efc,
  baby: 0xe56aa0,
  stop: 0xd24b4b,
};

const LIGHT_LABEL = new Set<SpaceKind>(["house", "spinToWin", "stop", "pet"]);
const CREAM = "#f6edd8";
const OFFSETS = [
  { x: -18, y: -12 },
  { x: 18, y: -12 },
  { x: -18, y: 14 },
  { x: 16, y: 16 },
];

function tokenPoint(space: Space, index: number): BoardPoint {
  const offset = OFFSETS[index] ?? { x: 0, y: 0 };
  return { x: space.x + offset.x, y: space.y + offset.y };
}

class TableScene extends Phaser.Scene {
  private tokens = new Map<string, Phaser.GameObjects.Image>();
  private names = new Map<string, Phaser.GameObjects.Text>();
  private ring!: Phaser.GameObjects.Graphics;
  private track: Phaser.GameObjects.Container | null = null;
  private follow: BoardPoint | null = null;
  private dragging = false;

  constructor() {
    super("table");
  }

  preload() {
    const colors: PegColor[] = ["red", "green", "blue", "purple"];
    for (const color of colors) this.load.image(color, `/tokens/${color}.png`);
  }

  create() {
    this.ring = this.add.graphics().setDepth(4);
    const camera = this.cameras.main;
    const pad = 360;
    camera.setBounds(-pad, -pad, BOARD_BOUNDS.width + pad * 2, BOARD_BOUNDS.height + pad * 2);
    camera.centerOn(BOARD_BOUNDS.width / 2, BOARD_BOUNDS.height / 2);
    this.fit();

    this.input.on("pointerdown", () => {
      this.dragging = true;
    });
    this.input.on("pointerup", () => {
      this.dragging = false;
    });
    this.input.on("pointermove", (pointer: Phaser.Input.Pointer) => {
      if (!pointer.isDown) return;
      const view = this.cameras.main;
      view.scrollX -= (pointer.x - pointer.prevPosition.x) / view.zoom;
      view.scrollY -= (pointer.y - pointer.prevPosition.y) / view.zoom;
    });
    this.input.on(
      "wheel",
      (_pointer: Phaser.Input.Pointer, _objects: unknown, _dx: number, dy: number) => {
        const view = this.cameras.main;
        view.setZoom(Phaser.Math.Clamp(view.zoom - dy * 0.001, 0.35, 1.5));
      },
    );
    this.scale.on("resize", () => this.fit());
  }

  update() {
    if (!this.follow || this.dragging) return;
    const camera = this.cameras.main;
    camera.scrollX += (this.follow.x - camera.midPoint.x) * 0.08;
    camera.scrollY += (this.follow.y - camera.midPoint.y) * 0.08;
  }

  show(state: GameState) {
    this.drawTrack(state);
    state.players.forEach((player, index) => {
      const point = this.parking(state, player, index);
      let token = this.tokens.get(player.id);
      if (!token) {
        token = this.add.image(point.x, point.y, player.color).setDisplaySize(46, 46).setDepth(5);
        this.tokens.set(player.id, token);
        const label = this.add
          .text(point.x, point.y + 28, player.name, {
            fontFamily: "Outfit, sans-serif",
            fontSize: "14px",
            color: CREAM,
          })
          .setOrigin(0.5, 0)
          .setResolution(2)
          .setDepth(6);
        this.names.set(player.id, label);
      }
      token.setPosition(point.x, point.y);
      this.names.get(player.id)?.setPosition(point.x, point.y + 28);
    });

    this.ring.clear();
    const active = state.players[state.current];
    if (active && state.phase !== "gameOver") {
      const point = this.parking(state, active, state.current);
      this.ring.lineStyle(3, 0xf6edd8, 1);
      this.ring.strokeCircle(point.x, point.y, 32);
      this.follow = point;
    }
  }

  move(playerId: string, frames: BoardPoint[]): Promise<void> {
    const token = this.tokens.get(playerId);
    const name = this.names.get(playerId);
    if (!token || frames.length === 0) return Promise.resolve();
    const index = stateIndex(this.tokens, playerId);
    const stepTo = (frame: BoardPoint) =>
      new Promise<void>((resolve) => {
        const point = {
          x: frame.x + (OFFSETS[index]?.x ?? 0),
          y: frame.y + (OFFSETS[index]?.y ?? 0),
        };
        this.tweens.add({
          targets: token,
          x: point.x,
          y: point.y,
          duration: 280,
          ease: "Sine.InOut",
          onUpdate: () => {
            name?.setPosition(token.x, token.y + 28);
            this.follow = { x: token.x, y: token.y };
            this.ring.clear();
            this.ring.lineStyle(3, 0xf6edd8, 1);
            this.ring.strokeCircle(token.x, token.y, 32);
          },
          onComplete: () => resolve(),
        });
      });
    return frames.reduce((chain, frame) => chain.then(() => stepTo(frame)), Promise.resolve());
  }

  private fit() {
    const byHeight = this.scale.height / BOARD_BOUNDS.height;
    this.cameras.main.setZoom(Phaser.Math.Clamp(byHeight * 1.15, 0.45, 1.2));
  }

  private drawTrack(state: GameState) {
    this.track?.destroy(true);
    const container = this.add.container(0, 0).setDepth(1);
    const graphics = this.add.graphics();
    container.add(graphics);
    graphics.fillStyle(0x214c38, 1);
    graphics.fillRect(0, 0, BOARD_BOUNDS.width, BOARD_BOUNDS.height);
    graphics.lineStyle(22, 0xf3e2bc, 1);
    for (const space of Object.values(state.board.spaces)) {
      for (const nextId of space.next) {
        const next = state.board.spaces[nextId];
        if (next) graphics.lineBetween(space.x, space.y, next.x, next.y);
      }
    }
    for (const space of Object.values(state.board.spaces)) {
      const radius = space.kind === "stop" ? 32 : 26;
      const outside = space.label.length > 5;
      graphics.fillStyle(FILL[space.kind], 1);
      graphics.fillCircle(space.x, space.y, radius);
      graphics.lineStyle(3, 0x241c14, 0.9);
      graphics.strokeCircle(space.x, space.y, radius);
      const caption = this.add
        .text(space.x, outside ? space.y + radius + 6 : space.y, space.label, {
          fontFamily: "Outfit, sans-serif",
          fontSize: "12px",
          color: outside || LIGHT_LABEL.has(space.kind) ? CREAM : "#241c14",
          fontStyle: "600",
        })
        .setOrigin(0.5, outside ? 0 : 0.5)
        .setResolution(2);
      container.add(caption);
    }
    this.track = container;
  }

  private parking(state: GameState, player: GameState["players"][number], index: number): BoardPoint {
    if (player.spaceId) {
      const space = state.board.spaces[player.spaceId];
      if (space) return tokenPoint(space, index);
    }
    const entryId = player.path
      ? player.path === "college"
        ? state.board.entries.college
        : state.board.entries.career
      : index % 2 === 0
        ? state.board.entries.college
        : state.board.entries.career;
    const entry = entryId ? state.board.spaces[entryId] : undefined;
    if (!entry) return { x: 90, y: 240 };
    const offset = OFFSETS[index] ?? { x: 0, y: 0 };
    return { x: entry.x + offset.x, y: entry.y + (player.path ? -78 : offset.y) };
  }
}

function stateIndex(tokens: Map<string, Phaser.GameObjects.Image>, playerId: string): number {
  return [...tokens.keys()].indexOf(playerId);
}

export function mountBoard(parent: HTMLElement): Promise<BoardApi> {
  return new Promise((resolve) => {
    let game: Phaser.Game;
    class BoundScene extends TableScene {
      create() {
        super.create();
        resolve({
          sync: (next) => this.show(next),
          animate: (playerId, frames) => this.move(playerId, frames),
          destroy: () => game.destroy(true),
        });
      }
    }
    game = new Phaser.Game({
      type: Phaser.AUTO,
      parent,
      backgroundColor: "#214c38",
      banner: false,
      scale: {
        mode: Phaser.Scale.RESIZE,
        width: Math.max(parent.clientWidth, 320),
        height: Math.max(parent.clientHeight, 320),
      },
      scene: [BoundScene],
    });
  });
}
