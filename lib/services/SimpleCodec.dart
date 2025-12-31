class SimpleCodec {
  static const Map<String, String> _map = {
    '{': 'A',
    '}': 'B',
    '"': 'C',
    ':': 'D',
    ',': 'E',
    '-': 'F',

    '0': 'G',
    '1': 'H',
    '2': 'I',
    '3': 'J',
    '4': 'K',
    '5': 'L',
    '6': 'M',
    '7': 'N',
    '8': 'O',
    '9': 'P',

    't': 'Q',
    'i': 'R',
    'd': 'S',
    'e': 'T',
  };

  static final Map<String, String> _reverseMap =
      _map.map((k, v) => MapEntry(v, k));

  static String encode(String input) {
    return input.split('').map((c) => _map[c] ?? c).join('');
  }

  static String decode(String input) {
    return input.split('').map((c) => _reverseMap[c] ?? c).join('');
  }
}