class PatientProfile {
  final String id;
  final String name;
  final String preferredLanguage;
  final String? photoUrl;

  const PatientProfile({
    required this.id,
    required this.name,
    required this.preferredLanguage,
    this.photoUrl,
  });
}