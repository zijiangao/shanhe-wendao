"use client";

import { useEffect, useMemo, useState } from "react";

type Save = { dust: number; total: number; sprouts: number; moths: number; pools: number; last: number };
const EMPTY: Save = { dust: 0, total: 0, sprouts: 0, moths: 0, pools: 0, last: Date.now() };
const STORE = "moon-garden-save-v1";

const compact = (value: number) =>
  value < 1000 ? Math.floor(value).toLocaleString() : Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 }).format(value);

export default function Home() {
  const [game, setGame] = useState<Save>(EMPTY);
  const [ready, setReady] = useState(false);
  const [offline, setOffline] = useState(0);
  const [pulse, setPulse] = useState(0);

  const perSecond = useMemo(() => game.sprouts + game.moths * 5 + game.pools * 24, [game]);
  const tapPower = 1 + game.sprouts * 0.25;
  const sproutCost = Math.ceil(15 * 1.55 ** game.sprouts);
  const mothCost = Math.ceil(125 * 1.62 ** game.moths);
  const poolCost = Math.ceil(850 * 1.68 ** game.pools);
  const level = Math.max(1, Math.floor(Math.log10(Math.max(1, game.total))) + 1);
  const nextGoal = 10 ** level;
  const progress = Math.min(100, (game.total / nextGoal) * 100);

  useEffect(() => {
    const raw = localStorage.getItem(STORE);
    if (raw) {
      try {
        const saved = { ...EMPTY, ...JSON.parse(raw) } as Save;
        const rate = saved.sprouts + saved.moths * 5 + saved.pools * 24;
        const earned = Math.min(rate * Math.max(0, (Date.now() - saved.last) / 1000), rate * 60 * 60 * 8);
        setOffline(earned);
        setGame({ ...saved, dust: saved.dust + earned, total: saved.total + earned, last: Date.now() });
      } catch { setGame(EMPTY); }
    }
    setReady(true);
  }, []);

  useEffect(() => {
    if (!ready) return;
    const tick = window.setInterval(() => {
      setGame((g) => {
        const rate = g.sprouts + g.moths * 5 + g.pools * 24;
        return { ...g, dust: g.dust + rate / 10, total: g.total + rate / 10, last: Date.now() };
      });
    }, 100);
    return () => clearInterval(tick);
  }, [ready]);

  useEffect(() => {
    if (!ready) return;
    const save = window.setInterval(() => localStorage.setItem(STORE, JSON.stringify({ ...game, last: Date.now() })), 2000);
    return () => clearInterval(save);
  }, [game, ready]);

  const gather = () => {
    setGame((g) => ({ ...g, dust: g.dust + tapPower, total: g.total + tapPower }));
    setPulse((p) => p + 1);
  };

  const buy = (kind: "sprouts" | "moths" | "pools", cost: number) => {
    if (game.dust < cost) return;
    setGame((g) => ({ ...g, dust: g.dust - cost, [kind]: g[kind] + 1 }));
  };

  if (!ready) return <main className="loading">Waking the garden…</main>;

  return (
    <main>
      <div className="stars" aria-hidden="true" />
      <header>
        <div className="brand"><span className="brand-mark">✦</span><span>Moon Garden</span></div>
        <div className="level-pill">Garden level {level}</div>
      </header>

      <section className="game-grid">
        <div className="garden-panel">
          <div className="eyebrow">A tiny idle game</div>
          <h1>Grow a garden<br />by moonlight.</h1>
          <p className="intro">Gather stardust, wake gentle helpers, and watch your quiet corner of the night come alive.</p>

          <button className="moon-button" onClick={gather} aria-label={`Gather ${tapPower.toFixed(1)} stardust`}>
            <span className="orbit orbit-one" />
            <span className="orbit orbit-two" />
            <span className="moon-face">☾</span>
            <span key={pulse} className={pulse ? "tap-burst" : ""}>+{tapPower.toFixed(tapPower % 1 ? 1 : 0)}</span>
          </button>
          <p className="tap-hint">Tap the moon to gather</p>
        </div>

        <div className="dashboard">
          <section className="resource-card">
            <div><span className="resource-label">Stardust</span><strong>{compact(game.dust)}</strong></div>
            <div className="rate"><span>✦</span> +{compact(perSecond)} / sec</div>
            <div className="goal-row"><span>Next garden level</span><span>{compact(game.total)} / {compact(nextGoal)}</span></div>
            <div className="progress"><i style={{ width: `${progress}%` }} /></div>
          </section>

          {offline > 0.5 && <button className="offline-note" onClick={() => setOffline(0)}>While you were away, the garden gathered <b>{compact(offline)} stardust</b>. <span>×</span></button>}

          <div className="section-title"><h2>Night helpers</h2><span>They keep working while you’re away</span></div>
          <div className="upgrades">
            <Upgrade icon="♧" name="Lunar Sprout" copy="A shy little source of light." owned={game.sprouts} rate="+1/sec" cost={sproutCost} canBuy={game.dust >= sproutCost} onBuy={() => buy("sprouts", sproutCost)} />
            <Upgrade icon="⌁" name="Dream Moth" copy="Carries stardust on soft wings." owned={game.moths} rate="+5/sec" cost={mothCost} canBuy={game.dust >= mothCost} onBuy={() => buy("moths", mothCost)} />
            <Upgrade icon="◉" name="Moon Pool" copy="Reflects whole constellations." owned={game.pools} rate="+24/sec" cost={poolCost} canBuy={game.dust >= poolCost} onBuy={() => buy("pools", poolCost)} />
          </div>

          <footer><span>Progress saves automatically on this device</span><button onClick={() => { if (confirm("Start a brand-new garden?")) { localStorage.removeItem(STORE); setGame({ ...EMPTY, last: Date.now() }); } }}>Reset garden</button></footer>
        </div>
      </section>
    </main>
  );
}

function Upgrade({ icon, name, copy, owned, rate, cost, canBuy, onBuy }: { icon: string; name: string; copy: string; owned: number; rate: string; cost: number; canBuy: boolean; onBuy: () => void }) {
  return <article className="upgrade-card">
    <div className="upgrade-icon">{icon}</div>
    <div className="upgrade-copy"><div className="name-row"><h3>{name}</h3><span>{owned}</span></div><p>{copy}</p><small>{rate}</small></div>
    <button disabled={!canBuy} onClick={onBuy}><span>✦</span>{compact(cost)}</button>
  </article>;
}
