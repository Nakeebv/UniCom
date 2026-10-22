import 'recording_service.dart';
import 'recording_service_web.dart';

/// Web: real browser capture via getUserMedia + MediaRecorder.
AudioRecordingService createRecordingService() => WebRecordingService();
