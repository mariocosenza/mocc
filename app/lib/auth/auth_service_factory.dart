import 'auth_config.dart';
import 'auth_service.dart';
import 'auth_service_stub.dart'
    if (dart.library.html) 'auth_service_web.dart'
    if (dart.library.io) 'auth_service_mobile.dart';

AuthService createAuthService(AuthConfig config) => createAuthServiceImpl(config);
