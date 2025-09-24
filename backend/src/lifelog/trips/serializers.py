from __future__ import annotations

from rest_framework import serializers

from .models import Trip, TripNode


class TripNodeSerializer(serializers.ModelSerializer):
    place_name = serializers.CharField(source="place.name", read_only=True)

    class Meta:
        model = TripNode
        fields = (
            "id",
            "place",
            "place_name",
            "sequence",
            "planned_stay_min",
            "transition_mode",
            "notes",
            "eta",
        )


class TripSerializer(serializers.ModelSerializer):
    nodes = TripNodeSerializer(many=True, read_only=True)

    class Meta:
        model = Trip
        fields = (
            "id",
            "title",
            "owner",
            "context_hash",
            "inputs",
            "duration_min",
            "budget_min",
            "budget_max",
            "mode",
            "freshness_score",
            "summary",
            "nodes",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("owner", "freshness_score")


class TripWriteSerializer(serializers.ModelSerializer):
    nodes = TripNodeSerializer(many=True)

    class Meta:
        model = Trip
        fields = (
            "id",
            "title",
            "context_hash",
            "inputs",
            "duration_min",
            "budget_min",
            "budget_max",
            "mode",
            "summary",
            "nodes",
        )

    def create(self, validated_data):
        nodes_data = validated_data.pop("nodes", [])
        trip = Trip.objects.create(**validated_data)
        self._sync_nodes(trip, nodes_data)
        return trip

    def update(self, instance, validated_data):
        nodes_data = validated_data.pop("nodes", None)
        trip = super().update(instance, validated_data)
        if nodes_data is not None:
            trip.nodes.all().delete()
            self._sync_nodes(trip, nodes_data)
        return trip

    def _sync_nodes(self, trip: Trip, nodes_data: list[dict]):
        for index, node_data in enumerate(nodes_data, start=1):
            TripNode.objects.create(
                trip=trip,
                sequence=node_data.get("sequence", index),
                place=node_data["place"],
                planned_stay_min=node_data.get("planned_stay_min", 30),
                transition_mode=node_data.get("transition_mode", TripNode.TransitionMode.WALK),
                notes=node_data.get("notes", {}),
                eta=node_data.get("eta"),
            )

