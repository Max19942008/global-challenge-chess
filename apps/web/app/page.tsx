'use client';

import { useState } from 'react';
import type { Color } from '@shaxmat/chess-core';
import { Game, type GameSetup } from '@/components/Game';
import { BOT_LEVELS, type BotLevel } from '@/lib/engine';

type ColorChoice = Color | 'random';

export default function Home() {
  const [setup, setSetup] = useState<GameSetup | null>(null);
  const [level, setLevel] = useState<BotLevel>('beginner');
  const [color, setColor] = useState<ColorChoice>('white');

  if (setup) return <Game setup={setup} onExit={() => setSetup(null)} />;

  const startBot = () => {
    const playerColor: Color = color === 'random' ? (Math.random() < 0.5 ? 'white' : 'black') : color;
    setSetup({ mode: 'bot', level, playerColor });
  };

  return (
    <main className="menu">
      <h1>Shaxmat</h1>
      <p className="sub">Bot bilan yoki bitta ekranda do'stingiz bilan o'ynang.</p>

      <section className="card">
        <h2>Bot bilan</h2>
        <div className="field">
          <span className="label">Daraja</span>
          <div className="seg" role="radiogroup" aria-label="Daraja">
            {(Object.keys(BOT_LEVELS) as BotLevel[]).map((l) => (
              <button key={l} role="radio" aria-checked={level === l} className={level === l ? 'on' : ''} onClick={() => setLevel(l)}>
                {BOT_LEVELS[l].label}
              </button>
            ))}
          </div>
        </div>
        <div className="field">
          <span className="label">Rangingiz</span>
          <div className="seg" role="radiogroup" aria-label="Rang">
            {(
              [
                ['white', 'Oq'],
                ['random', 'Tasodifiy'],
                ['black', 'Qora'],
              ] as [ColorChoice, string][]
            ).map(([c, label]) => (
              <button key={c} role="radio" aria-checked={color === c} className={color === c ? 'on' : ''} onClick={() => setColor(c)}>
                {label}
              </button>
            ))}
          </div>
        </div>
        <button className="primary" onClick={startBot}>
          Boshlash
        </button>
        <p className="note">Bot brauzeringizda ishlaydi. Bot o'yinlari reytingga ta'sir qilmaydi.</p>
      </section>

      <section className="card">
        <h2>Ikki kishi</h2>
        <p className="note">Bitta qurilmada navbatma-navbat o'ynang.</p>
        <button className="primary" onClick={() => setSetup({ mode: 'local' })}>
          Boshlash
        </button>
      </section>
    </main>
  );
}
