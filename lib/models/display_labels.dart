String matchStatusLabel(String status) => switch (status) {
  'pending' => 'Čeka odgovor',
  'accepted' => 'Dogovoren',
  'waiting_confirmation' => 'Potvrda rezultata',
  'confirmed' => 'Završen',
  'disputed' => 'Sporan rezultat',
  'rejected' => 'Odbijen',
  'cancelled' => 'Otkazan',
  _ => status,
};

String tournamentStatusLabel(String status) => switch (status) {
  'upcoming' => 'U najavi',
  'active' => 'U toku',
  'finished' => 'Završen',
  _ => status,
};

String surfaceLabel(String surface) => switch (surface.toLowerCase()) {
  'hard' => 'Tvrda podloga',
  'clay' => 'Šljaka',
  'grass' => 'Trava',
  _ => surface,
};

String shortDateTime(DateTime date) {
  final local = date.toLocal();
  return '${local.day}.${local.month}. · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
