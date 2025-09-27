from __future__ import annotations

from datetime import datetime, time
from typing import Iterable

from django.db import transaction
from django.db.models import F
from django.utils import timezone

from lifelog.users.models import UserBadge, UserStamp

from .models import Mission, MissionAssignment, MissionRewardLog


def assign_daily_missions_for_user(user, date: datetime.date | None = None) -> list[MissionAssignment]:
    """Ensure the user has all active daily missions for the given date."""
    date = date or timezone.localdate()
    assignments: list[MissionAssignment] = []
    active_missions = Mission.objects.filter(is_active=True, frequency=Mission.Frequency.DAILY)

    end_of_day = datetime.combine(date, time(23, 59, 59))
    if timezone.is_naive(end_of_day):
        end_of_day = timezone.make_aware(end_of_day)

    for mission in active_missions:
        assignment, _created = MissionAssignment.objects.get_or_create(
            user=user,
            mission=mission,
            date_for=date,
            defaults={"due_at": end_of_day},
        )
        assignments.append(assignment)
    return assignments


@transaction.atomic
def complete_assignment(assignment: MissionAssignment, metadata: dict | None = None) -> MissionAssignment:
    """Mark assignment complete and grant rewards once."""
    if assignment.status != MissionAssignment.Status.COMPLETED:
        assignment.mark_completed(metadata)
    elif metadata:
        assignment.result_metadata = {**assignment.result_metadata, **metadata}
        assignment.save(update_fields=["result_metadata"])

    if not assignment.reward_granted:
        _grant_reward(assignment)
    return assignment


def _grant_reward(assignment: MissionAssignment) -> None:
    mission = assignment.mission
    user = assignment.user

    if mission.reward_type == Mission.RewardType.CURRENCY:
        amount = mission.reward_amount
        if amount:
            user.profile_token_balance = F("profile_token_balance") + amount
            user.save(update_fields=["profile_token_balance"])
    elif mission.reward_type == Mission.RewardType.STAMP and mission.reward_code:
        UserStamp.objects.get_or_create(user=user, code=mission.reward_code)
    elif mission.reward_type == Mission.RewardType.BADGE and mission.reward_code:
        UserBadge.objects.get_or_create(user=user, code=mission.reward_code)

    MissionRewardLog.objects.create(
        assignment=assignment,
        reward_type=mission.reward_type,
        reward_code=mission.reward_code,
        reward_amount=mission.reward_amount,
    )

    assignment.reward_granted = True
    assignment.save(update_fields=["reward_granted"])

