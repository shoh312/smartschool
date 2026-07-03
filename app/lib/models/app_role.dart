enum AppRole { director, parent }

extension AppRoleLabel on AppRole {
  String get label => switch (this) {
    AppRole.director => 'Director',
    AppRole.parent => 'Parent',
  };
}
