String formatDateTimeYmdHms(String? raw, {String emptyFallback = 'TBA'}) {
  final input = (raw ?? '').trim();
  if (input.isEmpty) return emptyFallback;

  DateTime? parsed = DateTime.tryParse(input);
  parsed ??= DateTime.tryParse(input.replaceFirst(' ', 'T'));

  if (parsed == null) {
    final normalized = input.replaceAll('T', ' ');
    return normalized.length >= 10 ? normalized.substring(0, 10) : normalized;
  }

  final local = parsed.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatDateTimeFromDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
