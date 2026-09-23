"""Serializable domain contracts shared by the Godot bridge and analysis code."""

from dataclasses import dataclass
from enum import IntEnum, StrEnum
from typing import Any, TypeAlias


class Suit(StrEnum):
    CLUBS = "clubs"
    DIAMONDS = "diamonds"
    HEARTS = "hearts"
    SPADES = "spades"


class Rank(IntEnum):
    SIX = 6
    SEVEN = 7
    EIGHT = 8
    NINE = 9
    JACK = 10
    QUEEN = 11
    KING = 12
    TEN = 13  # In huutopussi 10 is more valuable than J, Q, K, so it is ranked higher than them.
    ACE = 14


@dataclass(frozen=True, slots=True)
class Card:
    suit: Suit
    rank: Rank


class Deck:
    """A standard 36-card deck used in Huutopussi."""

    cards: list[Card]

    def __init__(self) -> None:
        self.cards = [Card(suit, rank) for suit in Suit for rank in Rank]

    def __len__(self) -> int:
        return len(self.cards)

    def deal_single_card(self) -> Card:
        """Deal a single card from the deck."""
        if not self.cards:
            raise ValueError("No cards left in the deck.")
        return self.cards.pop()


@dataclass(frozen=True, slots=True)
class Action:
    """An action sent to the game engine; card_index is the hand-local index."""

    card_index: int
    bid: int | None = None
    declare_trump: Suit | None = None


@dataclass(frozen=True, slots=True)
class GameState:
    """Public observation data; private hands remain owned by the game engine."""

    current_player: int
    trump: Suit | None
    trick_cards: tuple[Card, ...]
    legal_action_mask: tuple[bool, ...]
    scores: tuple[int, ...]


JsonValue: TypeAlias = str | int | float | bool | None | list[Any] | dict[str, Any]


@dataclass(frozen=True, slots=True)
class EpisodeRecord:
    """One completed episode in a storage-friendly form."""

    episode_id: str
    seed: int
    reward: float
    steps: int
    winner: int | None
    metadata: dict[str, JsonValue]
