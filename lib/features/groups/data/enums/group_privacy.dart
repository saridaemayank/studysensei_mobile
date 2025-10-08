enum GroupPrivacy {
  public,
  private,
  inviteOnly,
}

extension GroupPrivacyExtension on GroupPrivacy {
  String get name {
    switch (this) {
      case GroupPrivacy.public:
        return 'Public';
      case GroupPrivacy.private:
        return 'Private';
      case GroupPrivacy.inviteOnly:
        return 'Invite Only';
    }
  }
}
