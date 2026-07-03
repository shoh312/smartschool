enum AppRole { director, parent, teacher }

extension AppRoleLabel on AppRole {
  String get label => switch (this) {
    AppRole.director => 'Director',
    AppRole.parent => 'Parent',
    AppRole.teacher => 'Teacher',
  };
}
