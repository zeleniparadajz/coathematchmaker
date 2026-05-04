class Player {
  const Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.birthDate,
    required this.country,
    required this.sport,
    required this.active,
    required this.totalPoints,
    required this.wins,
    required this.losses,
    required this.matchesPlayed,
    required this.tournamentsWon,
    required this.role,
    this.club,
    this.profileImage,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime birthDate;
  int get birthYear => birthDate.year;
  final String country;
  final String sport;
  final String? club;
  final String? profileImage;
  final bool active;
  final int totalPoints;
  final int wins;
  final int losses;
  final int matchesPlayed;
  final int tournamentsWon;
  final String role;

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'admin';

  factory Player.fromJson(Map<String, dynamic> json) {
    final rawBirthDate = json['birthDate']?.toString();
    final fallbackYear = json['birthYear'] ?? 1995;
    return Player(
      id: (json['_id'] ?? json['id']).toString(),
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      birthDate:
          DateTime.tryParse(rawBirthDate ?? '') ?? DateTime(fallbackYear),
      country: json['country'] ?? '',
      sport: json['sport'] ?? 'tennis',
      club: json['club'],
      profileImage: json['profileImage'],
      active: json['active'] ?? false,
      totalPoints: json['totalPoints'] ?? 0,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      matchesPlayed: json['matchesPlayed'] ?? 0,
      tournamentsWon: json['tournamentsWon'] ?? 0,
      role: json['role'] ?? 'player',
    );
  }
}
