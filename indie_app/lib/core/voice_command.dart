/// What a spoken utterance means for the composer.
class VoiceCommand {
  /// The text to put in the message box (already stripped of any send keyword).
  final String text;

  /// True when hands-free send is on and the utterance ended with a send keyword.
  final bool send;

  /// True when the whole utterance was a cancel word ("batal", "cancel"…): discard this dictation.
  final bool clear;

  const VoiceCommand(this.text, {this.send = false, this.clear = false});

  @override
  String toString() => 'VoiceCommand(text: "$text", send: $send, clear: $clear)';
}

const _clearWords = {'batal', 'cancel', 'hapus', 'hapus semua', 'clear', 'clear all'};

// "… kirim" / "… kirim pesan" / "… send" / "… send it": the keyword must END the utterance.
final _sendTail = RegExp(r'^(.*?)[\s,.;:!?]*\b(kirim(?: pesan| sekarang)?|send(?: it| message| now)?)[\s.!?]*$', caseSensitive: false);
final _trailingJunk = RegExp(r'[\s,.;:!?]+$');
final _whitespace = RegExp(r'\s+');

/// Turns a transcript into text plus an optional command.
///
/// Safety rules (the same ones the web preview implements and tests):
///  * the send keyword only counts when [handsFree] is on, and only at the very end;
///  * at least two words must remain, so "tolong kirim" is text, not a command;
///  * "resend" / "kirimkan" are ordinary words (the keyword must be a whole word).
VoiceCommand parseVoiceCommand(String raw, {bool handsFree = false}) {
  final t = raw.replaceAll(_whitespace, ' ').trim();
  final low = t.toLowerCase().replaceAll(RegExp(r'[.!?,;:\s]+$'), '');
  if (_clearWords.contains(low)) return const VoiceCommand('', clear: true);
  if (handsFree) {
    final m = _sendTail.firstMatch(t);
    if (m != null) {
      final rest = (m.group(1) ?? '').replaceAll(_trailingJunk, '').trim();
      if (rest.split(_whitespace).where((w) => w.isNotEmpty).length >= 2) return VoiceCommand(rest, send: true);
    }
  }
  return VoiceCommand(t);
}
