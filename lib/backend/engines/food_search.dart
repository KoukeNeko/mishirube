/// How well the search [words] find a food, or null when they do not.
///
/// Every word has to appear somewhere: in the [name], or in [elsewhere]
/// (the brand, the cup size and the brand's other spellings). The words
/// and both texts are already passed through `normalizeTerm`. A name that
/// starts with a word is tier 0, one that merely contains it tier 1, and
/// a match through [elsewhere] alone tier 2; lower is better.
int? foodMatchTier(List<String> words, String name, String elsewhere) {
  if (!words.every((w) => name.contains(w) || elsewhere.contains(w))) {
    return null;
  }
  final inName = words.where(name.contains).toList();
  return inName.isEmpty ? 2 : (inName.any(name.startsWith) ? 0 : 1);
}
