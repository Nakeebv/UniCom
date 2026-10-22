/// Platform-appropriate recorder factory. Web gets a real MediaRecorder
/// implementation; mobile/desktop uses the `record` package.
export 'recording_factory_io.dart'
    if (dart.library.js_interop) 'recording_factory_web.dart';
