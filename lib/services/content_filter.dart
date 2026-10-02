/// Client-side text safety filter for user-generated content.
///
/// Apple App Review guideline 1.2 requires a method to filter objectionable
/// material. This is a first line of defense applied before a post caption,
/// comment, or chat message is sent; reported content is additionally
/// triaged by admins in the moderation queue.
///
/// The word list is intentionally short and matched on whole words only
/// (word-boundary regex) so innocent words like "classic" or "Scunthorpe"
/// are never flagged, while "shit!" or "(gago)" still are. Keep additions
/// lowercase, single words or short phrases, and free of em-dashes.
class ContentFilter {
  static const List<String> _bannedWords = [
    // Severe profanity / slurs.
    'fuck',
    'shit',
    'bitch',
    'bastard',
    'asshole',
    'dickhead',
    'motherfucker',
    'cunt',
    'slut',
    'whore',
    'nigger',
    'nigga',
    'faggot',
    'retard',
    // Common Tagalog profanity (large PH user base).
    'putangina',
    'putang ina',
    'gago',
    'ulol',
    'tanga',
    'bobo',
    'pakyu',
    'kantot',
    'puke',
    'leche',
  ];

  /// Friendly refusal shown when [isAllowed] returns false.
  /// No em-dashes, per the project copy rules.
  static String get refusalMessage =>
      'That message did not pass our community check. '
      'Please keep it kind and try again.';

  /// Returns true when [text] contains none of the banned words.
  /// Matching is case-insensitive and whole-word only, using word
  /// boundaries so punctuation does not hide a banned word
  /// ("shit!" is caught; "classic" is not).
  static bool isAllowed(String text) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      final pattern = RegExp('\\b${RegExp.escape(word)}\\b');
      if (pattern.hasMatch(lower)) return false;
    }
    return true;
  }
}
