/// Platform API client facade: one PlatformSession hides all token
/// handling (storage, expiry tracking, mutex-serialized refresh, rotation
/// replay, 401 retry, session clearing) from app code.
library;

export "package:efa_platform_client/src/auth_client.dart"
    show AccountApiException, PlatformAccountInfo;
export "package:efa_platform_client/src/jwt.dart" show decodeJwtSubject;
export "package:efa_platform_client/src/platform_client.dart"
    show
        Comment,
        CommentListPage,
        PlatformApiException,
        PlatformStats,
        PlatformTimeWindow,
        PostListPage,
        PostRecord,
        PostSummary,
        ShipDetail,
        ShipListPage,
        ShipSummary,
        ThreadSummary,
        TopShip;
export "package:efa_platform_client/src/session.dart"
    show
        PlatformAuthRequiredException,
        PlatformIdentity,
        PlatformSession,
        platformApiProductionOrigin;
export "package:efa_platform_client/src/session_store.dart"
    show PlatformSessionStore, StoredPlatformSession;
