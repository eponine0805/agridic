import 'package:shared_preferences/shared_preferences.dart';

/// Persists post drafts to SharedPreferences so users can resume
/// composing after navigating away from the post create screen.
class PostDraftService {
  static const _keyTweetText = 'draft_tweet_text';
  static const _keyReportTitle = 'draft_report_title';
  static const _keyReportCrop = 'draft_report_crop';
  static const _keyReportLoc = 'draft_report_location';

  /// Returns true if a draft is saved.
  static Future<bool> hasDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyTweetText) ||
        prefs.containsKey(_keyReportTitle);
  }

  /// Loads saved draft fields. Missing fields return empty strings.
  static Future<Map<String, String>> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'tweetText': prefs.getString(_keyTweetText) ?? '',
      'reportTitle': prefs.getString(_keyReportTitle) ?? '',
      'reportCrop': prefs.getString(_keyReportCrop) ?? '',
      'reportLoc': prefs.getString(_keyReportLoc) ?? '',
    };
  }

  /// Saves a draft. Fields that are empty are removed from storage.
  static Future<void> saveDraft({
    required String tweetText,
    required String reportTitle,
    required String reportCrop,
    required String reportLoc,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (tweetText.isNotEmpty) {
      await prefs.setString(_keyTweetText, tweetText);
    } else {
      await prefs.remove(_keyTweetText);
    }
    if (reportTitle.isNotEmpty) {
      await prefs.setString(_keyReportTitle, reportTitle);
      await prefs.setString(_keyReportCrop, reportCrop);
      await prefs.setString(_keyReportLoc, reportLoc);
    } else {
      await prefs.remove(_keyReportTitle);
      await prefs.remove(_keyReportCrop);
      await prefs.remove(_keyReportLoc);
    }
  }

  /// Clears all saved draft fields.
  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTweetText);
    await prefs.remove(_keyReportTitle);
    await prefs.remove(_keyReportCrop);
    await prefs.remove(_keyReportLoc);
  }
}
