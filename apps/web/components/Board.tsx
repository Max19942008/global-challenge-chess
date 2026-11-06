'use client';

import { useEffect, useRef } from 'react';
import { Chessground } from '@lichess-org/chessground';
import type { Api } from '@lichess-org/chessground/api';
import type { Config } from '@lichess-org/chessground/config';
import type { Key } from '@lichess-org/chessground/types';
import type { Color } from '@shaxmat/chess-core';

export interface BoardProps {
  fen: string;
  orientation: Color;
  turnColor: Color;
  /** Which side the user may move now; undefined = nobody (bot thinking, game over). */
  movableColor: Color | 'both' | undefined;
  dests: Map<string, string[]>;
  lastMove?: [string, string];
  check: boolean;
  /** Bump to force the board back to `fen` (e.g. after a cancelled promotion). */
  version: number;
  onMove: (from: string, to: string) => void;
}

export function Board(props: BoardProps) {
  const el = useRef<HTMLDivElement>(null);
  const api = useRef<Api | null>(null);
  const onMoveRef = useRef(props.onMove);
  onMoveRef.current = props.onMove;

  const config = (): Config => ({
    fen: props.fen,
    orientation: props.orientation,
    turnColor: props.turnColor,
    check: props.check ? props.turnColor : false,
    lastMove: props.lastMove as Key[] | undefined,
    movable: {
      free: false,
      color: props.movableColor,
      dests: props.dests as Map<Key, Key[]>,
      showDests: true,
      events: { after: (orig, dest) => onMoveRef.current(orig, dest) },
    },
    premovable: { enabled: false },
    draggable: { showGhost: true },
    animation: { enabled: true, duration: 180 },
    highlight: { lastMove: true, check: true },
  });

  useEffect(() => {
    if (!el.current) return;
    api.current = Chessground(el.current, config());
    return () => {
      api.current?.destroy();
      api.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    api.current?.set(config());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [props.fen, props.orientation, props.turnColor, props.movableColor, props.dests, props.lastMove, props.check, props.version]);

  return <div ref={el} className="cg-wrap-host" />;
}
