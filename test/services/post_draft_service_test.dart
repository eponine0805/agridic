import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agridic/services/post_draft_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('hasDraft', () {
    test('returns false when no draft is saved', () async {
      expect(await PostDraftService.hasDraft(), isFalse);
    });

    test('returns true after saving tweet text', () async {
      await PostDraftService.saveDraft(
        tweetText: 'hello world',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      expect(await PostDraftService.hasDraft(), isTrue);
    });

    test('returns true after saving report title', () async {
      await PostDraftService.saveDraft(
        tweetText: '',
        reportTitle: 'Tomato blight',
        reportCrop: 'Tomato',
        reportLoc: 'Nakuru',
      );
      expect(await PostDraftService.hasDraft(), isTrue);
    });

    test('returns false after clearing draft', () async {
      await PostDraftService.saveDraft(
        tweetText: 'test',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      await PostDraftService.clearDraft();
      expect(await PostDraftService.hasDraft(), isFalse);
    });
  });

  group('saveDraft / loadDraft', () {
    test('tweet text roundtrip', () async {
      await PostDraftService.saveDraft(
        tweetText: 'my tweet text',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      final draft = await PostDraftService.loadDraft();
      expect(draft['tweetText'], 'my tweet text');
      expect(draft['reportTitle'], '');
    });

    test('report fields roundtrip', () async {
      await PostDraftService.saveDraft(
        tweetText: '',
        reportTitle: 'Stem borer attack',
        reportCrop: 'Maize',
        reportLoc: 'Kisumu',
      );
      final draft = await PostDraftService.loadDraft();
      expect(draft['reportTitle'], 'Stem borer attack');
      expect(draft['reportCrop'], 'Maize');
      expect(draft['reportLoc'], 'Kisumu');
      expect(draft['tweetText'], '');
    });

    test('empty tweet text removes key', () async {
      // Save, then overwrite with empty tweet
      await PostDraftService.saveDraft(
        tweetText: 'something',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      await PostDraftService.saveDraft(
        tweetText: '',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      expect(await PostDraftService.hasDraft(), isFalse);
    });

    test('empty report title removes report keys', () async {
      await PostDraftService.saveDraft(
        tweetText: '',
        reportTitle: 'Draft report',
        reportCrop: 'Bean',
        reportLoc: 'Meru',
      );
      await PostDraftService.saveDraft(
        tweetText: '',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      expect(await PostDraftService.hasDraft(), isFalse);
      final draft = await PostDraftService.loadDraft();
      expect(draft['reportTitle'], '');
      expect(draft['reportCrop'], '');
    });

    test('missing fields default to empty string', () async {
      final draft = await PostDraftService.loadDraft();
      expect(draft['tweetText'], '');
      expect(draft['reportTitle'], '');
      expect(draft['reportCrop'], '');
      expect(draft['reportLoc'], '');
    });
  });

  group('clearDraft', () {
    test('removes all saved draft fields', () async {
      await PostDraftService.saveDraft(
        tweetText: 'tweet',
        reportTitle: 'report',
        reportCrop: 'Maize',
        reportLoc: 'Nairobi',
      );
      await PostDraftService.clearDraft();
      expect(await PostDraftService.hasDraft(), isFalse);
      final draft = await PostDraftService.loadDraft();
      expect(draft['tweetText'], '');
      expect(draft['reportTitle'], '');
    });

    test('clear on empty draft does not throw', () async {
      await PostDraftService.clearDraft(); // should not throw
      expect(await PostDraftService.hasDraft(), isFalse);
    });

    test('can save new draft after clearing', () async {
      await PostDraftService.saveDraft(
        tweetText: 'old',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      await PostDraftService.clearDraft();
      await PostDraftService.saveDraft(
        tweetText: 'new',
        reportTitle: '',
        reportCrop: '',
        reportLoc: '',
      );
      final draft = await PostDraftService.loadDraft();
      expect(draft['tweetText'], 'new');
    });
  });
}
