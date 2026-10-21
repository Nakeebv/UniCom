/// Speech-voice options (demo catalog). A production deployment points these
/// ids at the configured TTS provider's voice inventory.
class VoiceOption {
  const VoiceOption(this.id, this.name, this.tag, this.flag);
  final String id;
  final String name;
  final String tag;
  final String flag;
}

abstract final class VoiceCatalog {
  static const List<VoiceOption> voices = [
    VoiceOption('aria', 'Aria', 'Warm · measured', '🇬🇧'),
    VoiceOption('kade', 'Kade', 'Deep · confident', '🇺🇸'),
    VoiceOption('zara', 'Zara', 'Bright · lively', '🇪🇸'),
    VoiceOption('yemi', 'Yẹmí', 'Natural · Yorùbá', '🇳🇬'),
    VoiceOption('amal', 'Amal', 'Clear · MSA', '🇸🇦'),
    VoiceOption('juma', 'Juma', 'Easy · Swahili', '🇰🇪'),
  ];
}
