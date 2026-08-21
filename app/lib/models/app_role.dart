enum AppRole { director, parent, teacher, student }

/// Whether this role talks to the school's own server on the LAN.
///
/// Cameras, live attendance, lesson planning and staff management only exist
/// there, and only staff open those. Parents and pupils read everything from
/// the Public Server, so making them wait on a LAN broadcast they will never
/// get an answer to -- they are usually at home -- just delays every launch.
///
/// Null means nobody is signed in yet: the login screen has to be ready for a
/// director or teacher, so it resolves the LAN address too.
bool roleUsesSchoolServer(AppRole? role) =>
    role == null || role == AppRole.director || role == AppRole.teacher;

extension AppRoleLabel on AppRole {
  String get label => switch (this) {
    AppRole.director => 'Director',
    AppRole.parent => 'Parent',
    AppRole.teacher => 'Teacher',
    AppRole.student => 'Student',
  };
}
