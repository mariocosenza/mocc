import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/notification_service.dart';
import 'package:mocc/service/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final client = ref.watch(graphQLClientProvider);
  return UserService(client);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final userService = ref.watch(userServiceProvider);
  return NotificationService(userService);
});
