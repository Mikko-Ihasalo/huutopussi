"""Analysis related stuff for huutopussi_rl."""

from math import comb

from huutopussi_rl.domain import Deck
import numpy as np
import pandas as pd

SUITS = ["clubs", "diamonds", "hearts", "spades"]
HAND_SIZE = 10
DEVIL_SIZE = 6
DECK_SIZE = 36


class HuutopussiSimulation:
    """A class for simulating huutopussi games."""

    def __init__(self):
        self.deck = Deck()
        self.player_1_hand = []
        self.player_2_hand = []
        self.player_3_hand = []
        self.devils_deck = []

    def simulate_deal(self):
        """Simulate a single deal of huutopussi."""
        self.deck = Deck()
        np.random.shuffle(self.deck.cards)
        self.player_1_hand = [self.deck.deal_single_card() for _ in range(10)]
        self.player_2_hand = [self.deck.deal_single_card() for _ in range(10)]
        self.player_3_hand = [self.deck.deal_single_card() for _ in range(10)]
        self.devils_deck = [self.deck.deal_single_card() for _ in range(6)]
        return {
            "player_1": self.player_1_hand,
            "player_2": self.player_2_hand,
            "player_3": self.player_3_hand,
            "devils": self.devils_deck,
        }

    def simulate_statistics(self, num_simulations: int) -> pd.DataFrame:
        """Simulate multiple deals and collect statistics."""

        stats = []
        for _ in range(num_simulations):
            deal = self.simulate_deal()
            eval_before_devil, eval_after_devil = (
                evaluate_winning_and_trump_combos_in_deal(deal)
            )
            eval_before_aces, eval_after_aces = evaluate_winning_and_aces_in_deal(deal)
            stats.append(
                {
                    **eval_before_devil,
                    **eval_after_devil,
                    **eval_before_aces,
                    **eval_after_aces,
                }
            )
        return pd.DataFrame(stats)


def calculate_count_of_certain_cards_in_hand(hand: list, rank: int) -> int:
    """Calculate the count of cards with a specific rank in each player's hand."""
    return sum(1 for card in hand if card.rank == rank)


def calculate_count_of_certain_cards_in_deal(deal: dict, rank: int) -> dict:
    """Calculate the count of cards with a specific rank in each player's hand."""
    return {
        "player_1": calculate_count_of_certain_cards_in_hand(deal["player_1"], rank),
        "player_2": calculate_count_of_certain_cards_in_hand(deal["player_2"], rank),
        "player_3": calculate_count_of_certain_cards_in_hand(deal["player_3"], rank),
        "devils": calculate_count_of_certain_cards_in_hand(deal["devils"], rank),
    }


def probability_of_total_aces_given_hand(
    aces_in_hand: int,
    total_aces: int,
) -> float:
    """Return the probability of having a certain number of aces after devils deck, given the number of aces in hand."""

    aces_remaining = 4 - aces_in_hand
    cards_remaining = 26
    new_aces = total_aces - aces_in_hand
    non_aces_remaining = cards_remaining - aces_remaining

    if not 0 <= new_aces <= DEVIL_SIZE:
        return 0.0
    if new_aces > aces_remaining or DEVIL_SIZE - new_aces > non_aces_remaining:
        return 0.0

    return (
        comb(aces_remaining, new_aces)
        * comb(non_aces_remaining, DEVIL_SIZE - new_aces)
        / comb(cards_remaining, DEVIL_SIZE)
    )


def probability_of_total_trump_combos_given_hand(
    complete_combos: int,
    singleton_halves: int,
) -> dict[int, float]:
    """Return probabilities for the total Q-K combos after the devil deck.

    ``singleton_halves`` counts suits where the hand contains exactly one of
    the queen or king.  The devil deck can complete one of those suits, or it
    can contain both cards of a suit with no Q/K currently in the hand.
    """

    cards_remaining = DECK_SIZE - HAND_SIZE
    absent_suit_pairs = 4 - complete_combos - singleton_halves
    remaining_trump_cards = 2 * absent_suit_pairs + singleton_halves
    non_trump_cards = cards_remaining - remaining_trump_cards
    denominator = comb(cards_remaining, DEVIL_SIZE)
    probabilities = {total: 0.0 for total in range(5)}

    # Choose singleton complements, complete absent-suit pairs, and partial
    # absent-suit pairs; every other devil card is unrelated to Q/K combos.
    for completed_singletons in range(singleton_halves + 1):
        for completed_pairs in range(absent_suit_pairs + 1):
            for partial_pairs in range(absent_suit_pairs - completed_pairs + 1):
                selected_non_trump = DEVIL_SIZE - (
                    completed_singletons + 2 * completed_pairs + partial_pairs
                )
                if not 0 <= selected_non_trump <= non_trump_cards:
                    continue

                ways = (
                    comb(singleton_halves, completed_singletons)
                    * comb(absent_suit_pairs, completed_pairs)
                    * comb(absent_suit_pairs - completed_pairs, partial_pairs)
                    * 2**partial_pairs
                    * comb(non_trump_cards, selected_non_trump)
                )
                total_combos = complete_combos + completed_singletons + completed_pairs
                probabilities[total_combos] += ways / denominator

    return probabilities


def calculate_trump_combos_in_hand(
    hand: list,
) -> dict:
    """Calculate what trump combinations are in a player's hand.

    A combination of king and queen of the same suit is considered a trump combination.
    """
    trumps = {}
    for suit in SUITS:
        suit_cards = [card.rank for card in hand if card.suit.value == suit]
        if 11 in suit_cards and 12 in suit_cards:
            trumps[suit] = 1
    return trumps


def evaluate_winning_and_trump_combos_in_deal(deal: dict) -> tuple[dict, dict]:
    """Evaluate the winning and trump combinations in a deal."""
    eval_before_devil = {
        "trumps_before_devil_0": 0,
        "trumps_before_devil_1": 0,
        "trumps_before_devil_2": 0,
        "trumps_before_devil_3": 0,
        "trumps_before_devil_4": 0,
    }
    eval_after_devil = {
        "trumps_after_devil_0": 0,
        "trumps_after_devil_1": 0,
        "trumps_after_devil_2": 0,
        "trumps_after_devil_3": 0,
        "trumps_after_devil_4": 0,
    }
    for player in ["player_1", "player_2", "player_3"]:
        trumps = calculate_trump_combos_in_hand(deal[player])
        eval_before_devil[f"trumps_before_devil_{len(trumps)}"] += 1
        trumps_after_devil = calculate_trump_combos_in_hand(
            deal[player] + deal["devils"]
        )
        eval_after_devil[f"trumps_after_devil_{len(trumps_after_devil)}"] += 1
    return eval_before_devil, eval_after_devil


def evaluate_winning_and_aces_in_deal(deal: dict) -> tuple[dict, dict]:
    """Evaluate the winning and aces in a deal."""
    eval_before_devil = {
        "aces_before_devil_0": 0,
        "aces_before_devil_1": 0,
        "aces_before_devil_2": 0,
        "aces_before_devil_3": 0,
        "aces_before_devil_4": 0,
    }
    eval_after_devil = {
        "aces_after_devil_0": 0,
        "aces_after_devil_1": 0,
        "aces_after_devil_2": 0,
        "aces_after_devil_3": 0,
        "aces_after_devil_4": 0,
    }
    for player in ["player_1", "player_2", "player_3"]:
        aces = calculate_count_of_certain_cards_in_hand(deal[player], 14)
        eval_before_devil[f"aces_before_devil_{aces}"] += 1
        aces_after_devil = calculate_count_of_certain_cards_in_hand(
            deal[player] + deal["devils"], 14
        )
        eval_after_devil[f"aces_after_devil_{aces_after_devil}"] += 1
    return eval_before_devil, eval_after_devil
