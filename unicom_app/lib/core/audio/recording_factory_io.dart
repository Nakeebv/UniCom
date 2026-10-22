import 'recording_service.dart';

/// Mobile/desktop: real microphone via the `record` package.
AudioRecordingService createRecordingService() => NativeRecordingService();
