from rest_framework.routers import DefaultRouter

from lifelog.analytics.views import DailyProductMetricViewSet
from lifelog.feedback.views import FeedbackViewSet
from lifelog.missions.views import MissionAssignmentViewSet, MissionViewSet
from lifelog.notifications.views import NotificationViewSet, PushSubscriptionViewSet
from lifelog.party.views import PartyMemberViewSet, PartyPositionViewSet, PartySessionViewSet
from lifelog.places.views import PlaceViewSet, TagViewSet
from lifelog.posts.views import PostViewSet
from lifelog.trips.views import TripViewSet
from lifelog.users.views import UserViewSet

router = DefaultRouter()
router.register("users", UserViewSet, basename="user")
router.register("places", PlaceViewSet, basename="place")
router.register("tags", TagViewSet, basename="tag")
router.register("posts", PostViewSet, basename="post")
router.register("trips", TripViewSet, basename="trip")
router.register("missions", MissionViewSet, basename="mission")
router.register("mission-assignments", MissionAssignmentViewSet, basename="mission-assignment")
router.register("feedback", FeedbackViewSet, basename="feedback")
router.register("party/sessions", PartySessionViewSet, basename="party-session")
router.register("party/positions", PartyPositionViewSet, basename="party-position")
router.register("party/members", PartyMemberViewSet, basename="party-member")
router.register("notifications", NotificationViewSet, basename="notification")
router.register("push-subscriptions", PushSubscriptionViewSet, basename="push-subscription")
router.register("analytics/metrics", DailyProductMetricViewSet, basename="analytics-metric")

urlpatterns = router.urls
