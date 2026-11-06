import 'react';

// chessground's piece sprites are styled on a custom <piece> element.
declare module 'react' {
  namespace JSX {
    interface IntrinsicElements {
      piece: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>;
    }
  }
}
