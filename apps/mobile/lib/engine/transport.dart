/// A line-based UCI connection to a Stockfish process.
///
/// Android/iOS use the native multistockfish build; a browser (used to try the
/// app on a PC) uses the same Stockfish 19 lite WASM build as the web app.
library;

export 'transport_base.dart';
export 'transport_stub.dart'
    if (dart.library.js_interop) 'transport_web.dart'
    if (dart.library.ffi) 'transport_native.dart';
