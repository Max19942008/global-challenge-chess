'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ChessGame, type Color, type EndReason, type GameStatus, type PromotionPiece } from '@shaxmat/chess-core';
import { Board } from './Board';
import { BOT_LEVELS, StockfishEngine, type BotLevel } from '@/lib/engine';

export type GameSetup =
  | { mode: 'local' }
  | { mode: 'bot'; level: BotLevel; playerColor: Color };

const COLOR_NAME: Record<Color, string> = { white: 'Oqlar', black: 'Qoralar' };

const REASON_TEXT: Record<EndReason, string> = {
  checkmate: 'Mat',
  stalemate: 'Pat',
  threefold: 'Uch marta takrorlanish',
  'fifty-move': '50 yurish qoidasi',
  insufficient: 'Material yetarli emas',
  resign: "Taslim bo'ldi",
  timeout: 'Vaqt tugadi',
  abandon: 'Tashlab ketildi',
  'draw-agreed': 'Durangga kelishildi',
  aborted: 'Bekor qilindi',
};

const PROMO_PIECES: { p: PromotionPiece; name: string }[] = [
  { p: 'q', name: 'queen' },
  { p: 'r', name: 'rook' },
  { p: 'b', name: 'bishop' },
  { p: 'n', name: 'knight' },
];

const other = (c: Color): Color => (c === 'white' ? 'black' : 'white');

function statusText(s: GameStatus, resigned: Color | null): string {
  if (resigned) return `${COLOR_NAME[resigned]} taslim bo'ldi — ${COLOR_NAME[other(resigned)].toLowerCase()} yutdi`;
  if (s.over && s.reason) {
    if (s.result === '1/2-1/2') return `${REASON_TEXT[s.reason]} — durang`;
    const winner: Color = s.result === '1-0' ? 'white' : 'black';
    return `${REASON_TEXT[s.reason]} — ${COLOR_NAME[winner].toLowerCase()} yutdi`;
  }
  return `${COLOR_NAME[s.turn]} navbati${s.check ? ' — shah!' : ''}`;
}

export function Game({ setup, onExit }: { setup: GameSetup; onExit: () => void }) {
  const game = useRef(new ChessGame());
  const [version, setVersion] = useState(0);
  const [promotion, setPromotion] = useState<{ from: string; to: string; color: Color } | null>(null);
  const [resigned, setResigned] = useState<Color | null>(null);
  const [thinking, setThinking] = useState(false);
  const [engineError, setEngineError] = useState<string | null>(null);
  const [orientation, setOrientation] = useState<Color>(setup.mode === 'bot' ? setup.playerColor : 'white');
  const engine = useRef<StockfishEngine | null>(null);
  /** Incremented on new game / undo so a stale engine reply is ignored. */
  const epoch = useRef(0);

  const bump = () => setVersion((v) => v + 1);
  const g = game.current;
  const status = g.status();
  const over = status.over || resigned !== null;
  const botColor = setup.mode === 'bot' ? other(setup.playerColor) : null;

  useEffect(() => {
    if (setup.mode !== 'bot') return;
    const e = new StockfishEngine();
    engine.current = e;
    e.newGame(setup.level).catch((err) => setEngineError(String(err)));
    return () => {
      e.terminate();
      engine.current = null;
    };
  }, [setup]);

  const botMove = useCallback(async () => {
    if (setup.mode !== 'bot' || !engine.current) return;
    const myEpoch = epoch.current;
    setThinking(true);
    try {
      const uci = await engine.current.bestMove(game.current.fen, BOT_LEVELS[setup.level].movetimeMs);
      if (myEpoch !== epoch.current) return;
      if (uci && game.current.move(uci)) bump();
    } catch (err) {
      setEngineError(String(err));
    } finally {
      if (myEpoch === epoch.current) setThinking(false);
    }
  }, [setup]);

  // Bot moves whenever it is its turn (also covers "play as black": bot opens).
  useEffect(() => {
    if (botColor && !over && !thinking && g.turn() === botColor) void botMove();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [version, botColor]);

  const commit = (uci: string) => {
    if (!game.current.move(uci)) {
      bump(); // illegal (should not happen): snap board back
      return;
    }
    bump();
  };

  const onMove = (from: string, to: string) => {
    if (g.isPromotion(from, to)) {
      setPromotion({ from, to, color: g.turn() });
      return;
    }
    commit(from + to);
  };

  const choosePromotion = (p: PromotionPiece | null) => {
    const pending = promotion;
    setPromotion(null);
    if (!pending || !p) {
      bump(); // cancelled: put the pawn back
      return;
    }
    commit(pending.from + pending.to + p);
  };

  const undo = () => {
    if (thinking && setup.mode === 'bot') return;
    epoch.current++;
    setResigned(null);
    if (setup.mode === 'bot') {
      // Take back to the player's own turn.
      g.undo();
      if (g.turn() !== setup.playerColor) g.undo();
    } else g.undo();
    setThinking(false);
    bump();
  };

  const restart = () => {
    epoch.current++;
    game.current = new ChessGame();
    setResigned(null);
    setPromotion(null);
    setThinking(false);
    if (setup.mode === 'bot') engine.current?.newGame(setup.level).catch((err) => setEngineError(String(err)));
    bump();
  };

  const resign = () => {
    if (over) return;
    epoch.current++;
    setThinking(false);
    setResigned(setup.mode === 'bot' ? setup.playerColor : g.turn());
  };

  const dests = useMemo(() => g.legalDests(), [g, version]);
  const lastMove = useMemo(() => g.lastMove(), [g, version]);
  const history = g.history();

  let movableColor: Color | 'both' | undefined;
  if (over || promotion) movableColor = undefined;
  else if (setup.mode === 'local') movableColor = 'both';
  else movableColor = g.turn() === setup.playerColor ? setup.playerColor : undefined;

  const pairs: { n: number; w?: string; b?: string }[] = [];
  history.forEach((m, i) => {
    if (i % 2 === 0) pairs.push({ n: i / 2 + 1, w: m.san });
    else pairs[pairs.length - 1]!.b = m.san;
  });

  const topColor = other(orientation);
  const playerLabel = (c: Color) => {
    if (setup.mode === 'bot' && c === botColor) return { name: `Bot · ${BOT_LEVELS[setup.level].label}`, bot: true };
    if (setup.mode === 'bot') return { name: 'Siz', bot: false };
    return { name: COLOR_NAME[c], bot: false };
  };
  const PlayerBar = ({ c }: { c: Color }) => {
    const p = playerLabel(c);
    const active = !over && g.turn() === c;
    return (
      <div className={`player ${active ? 'active' : ''}`}>
        <span className={`swatch ${c}`} aria-hidden />
        <span className="pname">{p.name}</span>
        {p.bot && <span className="badge">BOT</span>}
        {p.bot && thinking && <span className="thinking">o'ylamoqda…</span>}
      </div>
    );
  };

  return (
    <div className="game">
      <div className="board-col">
        <PlayerBar c={topColor} />
        <div className="board-box">
          <Board
            fen={g.fen}
            orientation={orientation}
            turnColor={g.turn()}
            movableColor={movableColor}
            dests={dests}
            lastMove={lastMove}
            check={status.check}
            version={version}
            onMove={onMove}
          />
          {promotion && (
            <div className="promo" role="dialog" aria-label="Piyoda aylanishi">
              <div className="promo-card">
                <p>Piyoda nimaga aylansin?</p>
                <div className="promo-row cg-wrap">
                  {PROMO_PIECES.map(({ p, name }) => (
                    <button key={p} className="promo-btn" onClick={() => choosePromotion(p)} aria-label={name}>
                      <piece className={`${promotion.color} ${name}`} />
                    </button>
                  ))}
                </div>
                <button className="link" onClick={() => choosePromotion(null)}>
                  Bekor qilish
                </button>
              </div>
            </div>
          )}
        </div>
        <PlayerBar c={orientation} />
      </div>

      <aside className="side">
        <div className={`status ${over ? 'over' : ''}`}>{statusText(status, resigned)}</div>
        {engineError && <div className="error">Dvigatel xatosi: {engineError}</div>}
        <ol className="moves">
          {pairs.length === 0 && <li className="empty">Hali yurish yo'q</li>}
          {pairs.map((p) => (
            <li key={p.n}>
              <span className="mn">{p.n}.</span>
              <span>{p.w}</span>
              <span>{p.b ?? ''}</span>
            </li>
          ))}
        </ol>
        <div className="actions">
          <button onClick={undo} disabled={history.length === 0 || (setup.mode === 'bot' && thinking)}>
            Ortga
          </button>
          <button onClick={() => setOrientation(other(orientation))}>Taxtani burish</button>
          <button onClick={resign} disabled={over}>
            Taslim bo'lish
          </button>
          <button onClick={restart}>Yangi o'yin</button>
          <button className="ghost" onClick={onExit}>
            Menyu
          </button>
        </div>
        {over && history.length > 0 && (
          <details className="pgn">
            <summary>PGN</summary>
            <textarea readOnly value={g.pgn()} rows={5} />
          </details>
        )}
      </aside>
    </div>
  );
}
