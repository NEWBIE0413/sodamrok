from __future__ import annotations

from django.contrib.auth import get_user_model
from django.utils import timezone
from django.test import TestCase

from lifelog.missions import services
from lifelog.missions.models import Mission, MissionAssignment, MissionRewardLog
from lifelog.users.models import UserBadge, UserStamp


class DailyMissionServiceTests(TestCase):
    def setUp(self):
        self.User = get_user_model()
        self.user = self.User.objects.create_user(email="daily@example.com", password="DailyPass123!")

    def test_assign_daily_missions_creates_assignments(self):
        mission = Mission.objects.create(
            title="Visit a calm cafe",
            frequency=Mission.Frequency.DAILY,
            reward_type=Mission.RewardType.CURRENCY,
            reward_amount=25,
        )

        assignments = services.assign_daily_missions_for_user(self.user)
        self.assertEqual(len(assignments), 1)
        assignment = assignments[0]
        self.assertEqual(assignment.mission, mission)
        self.assertEqual(assignment.status, MissionAssignment.Status.PENDING)
        self.assertIsNotNone(assignment.due_at)

    def test_complete_assignment_grants_currency_reward(self):
        mission = Mission.objects.create(
            title="Share a photo",
            frequency=Mission.Frequency.DAILY,
            reward_type=Mission.RewardType.CURRENCY,
            reward_amount=40,
        )
        assignment = MissionAssignment.objects.create(
            user=self.user,
            mission=mission,
            date_for=timezone.localdate(),
        )

        services.complete_assignment(assignment)
        self.user.refresh_from_db()
        assignment.refresh_from_db()

        self.assertEqual(self.user.profile_token_balance, 40)
        self.assertTrue(assignment.reward_granted)
        self.assertTrue(MissionRewardLog.objects.filter(assignment=assignment).exists())

    def test_complete_assignment_awards_stamp(self):
        mission = Mission.objects.create(
            title="Collect a stamp",
            frequency=Mission.Frequency.DAILY,
            reward_type=Mission.RewardType.STAMP,
            reward_code="STAMP_CALM_DAY",
        )
        assignment = MissionAssignment.objects.create(
            user=self.user,
            mission=mission,
            date_for=timezone.localdate(),
        )

        services.complete_assignment(assignment)

        self.assertTrue(UserStamp.objects.filter(user=self.user, code="STAMP_CALM_DAY").exists())
        self.assertTrue(assignment.reward_granted)

    def test_complete_assignment_awards_badge(self):
        mission = Mission.objects.create(
            title="Unlock badge",
            frequency=Mission.Frequency.DAILY,
            reward_type=Mission.RewardType.BADGE,
            reward_code="BADGE_FRIENDLY",
        )
        assignment = MissionAssignment.objects.create(
            user=self.user,
            mission=mission,
            date_for=timezone.localdate(),
        )

        services.complete_assignment(assignment)

        self.assertTrue(UserBadge.objects.filter(user=self.user, code="BADGE_FRIENDLY").exists())
