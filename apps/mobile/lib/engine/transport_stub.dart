import 'transport_base.dart';

Future<UciTransport> openTransport() =>
    Future.error(UnsupportedError('No Stockfish build for this platform'));
