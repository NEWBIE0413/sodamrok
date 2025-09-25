import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import '../network/dio_client.dart';
import '../network/auth_interceptor.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/auth/data/storage/token_storage.dart';
import '../../features/home/data/repositories/mock_home_feed_repository.dart';
import '../../features/home/data/services/home_feed_service.dart';
import '../../features/home/data/services/post_interaction_service.dart';
import '../../features/home/domain/repositories/home_feed_repository.dart';

class AppDependencies {
  AppDependencies._();

  static final DioClient dioClient = DioClient();
  static late final HomeFeedService _homeFeedService;
  static const MockHomeFeedRepository _mockHomeFeedRepository = MockHomeFeedRepository();
  static late final PostInteractionService postInteractionService;
  static late final AuthService _authService;
  static late final TokenStorage _tokenStorage;
  static late final AuthController authController;

  static bool _configured = false;

  static HomeFeedRepository get homeFeedRepository =>
      Environment.useMockFeed ? _mockHomeFeedRepository : _homeFeedService;

  static Future<void> configure() async {
    if (_configured) {
      return;
    }

    dioClient.configure(
      baseUrl: Environment.apiBaseUrl,
      headers: Environment.defaultHeaders(),
    );

    _homeFeedService = HomeFeedService(dioClient);
    postInteractionService = PostInteractionService(dioClient);

    final sharedPreferences = await SharedPreferences.getInstance();
    _tokenStorage = TokenStorage(sharedPreferences);
    _authService = AuthService(dioClient);
    authController = AuthController(
      authService: _authService,
      tokenStorage: _tokenStorage,
      dioClient: dioClient,
    );
    dioClient.addInterceptor(AuthInterceptor(dioClient.dio, authController));
    await authController.initialize();

    _configured = true;
  }
}
