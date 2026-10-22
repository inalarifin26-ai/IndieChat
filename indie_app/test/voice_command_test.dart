import 'package:flutter_test/flutter_test.dart';
import 'package:indie_app/core/voice_command.dart';

void main() {
  group('parseVoiceCommand — hands-free on', () {
    test('trailing send keyword sends the cleaned text', () {
      for (final (said, text) in [
        ('buat laporan mingguan kirim', 'buat laporan mingguan'),
        ('Buat laporan mingguan, kirim.', 'Buat laporan mingguan'),
        ('create a weekly report send it', 'create a weekly report'),
        ('summarize my inbox send message', 'summarize my inbox'),
      ]) {
        final c = parseVoiceCommand(said, handsFree: true);
        expect(c.send, isTrue, reason: said);
        expect(c.text, text, reason: said);
        expect(c.clear, isFalse);
      }
    });

    test('the keyword must end the utterance', () {
      final c = parseVoiceCommand('kirim laporan ke Sarah', handsFree: true);
      expect(c.send, isFalse);
      expect(c.text, 'kirim laporan ke Sarah');
    });

    test('too short to auto-send', () {
      expect(parseVoiceCommand('tolong kirim', handsFree: true).send, isFalse);
      expect(parseVoiceCommand('kirim', handsFree: true).send, isFalse);
    });

    test('whole words only', () {
      final c = parseVoiceCommand('I want to resend', handsFree: true);
      expect(c.send, isFalse);
      expect(c.text, 'I want to resend');
    });
  });

  group('parseVoiceCommand — hands-free off', () {
    test('the keyword is just text', () {
      final c = parseVoiceCommand('buat laporan mingguan kirim');
      expect(c.send, isFalse);
      expect(c.text, 'buat laporan mingguan kirim');
    });
  });

  group('parseVoiceCommand — cancel words', () {
    test('a cancel word discards the dictation (with or without hands-free)', () {
      for (final hf in [true, false]) {
        for (final said in ['  batal. ', 'Cancel', 'hapus semua']) {
          final c = parseVoiceCommand(said, handsFree: hf);
          expect(c.clear, isTrue, reason: '$said / $hf');
          expect(c.text, '');
        }
      }
    });

    test('a longer sentence that merely starts with one is text', () {
      final c = parseVoiceCommand('batalkan pesanan');
      expect(c.clear, isFalse);
      expect(c.text, 'batalkan pesanan');
    });
  });

  test('empty input is empty text', () {
    final c = parseVoiceCommand('', handsFree: true);
    expect([c.text, c.send, c.clear], ['', false, false]);
  });
}
