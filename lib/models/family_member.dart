class FamilyMember {
  final String id;
  final String name;
  final String relationship;
  final String? photoUrl;
  final String? phoneNumber;
  final String? voiceMessage;
  final String? memoryNote;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    this.photoUrl,
    this.phoneNumber,
    this.voiceMessage,
    this.memoryNote,
  });
}