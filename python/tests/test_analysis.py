from math import comb

import pytest

from huutopussi_rl.analysis import (
    probability_of_total_aces_given_hand,
    probability_of_total_trump_combos_given_hand,
)


def test_conditional_ace_probabilities_sum_to_one() -> None:
    probabilities = [
        probability_of_total_aces_given_hand(aces_in_hand=1, total_aces=total)
        for total in range(5)
    ]
    assert sum(probabilities) == pytest.approx(1.0)


def test_conditional_ace_probability_uses_remaining_aces() -> None:
    probability = probability_of_total_aces_given_hand(aces_in_hand=1, total_aces=2)
    expected = (comb(3, 1) * comb(23, 5)) / comb(26, 6)
    assert probability == pytest.approx(expected)


def test_conditional_trump_probabilities_sum_to_one() -> None:
    probabilities = probability_of_total_trump_combos_given_hand(
        complete_combos=1,
        singleton_halves=2,
    )
    assert sum(probabilities.values()) == pytest.approx(1.0)


def test_trump_probability_counts_a_completed_half_as_a_new_combo() -> None:
    probabilities = probability_of_total_trump_combos_given_hand(
        complete_combos=0,
        singleton_halves=1,
    )
    assert probabilities[1] > 0
    assert probabilities[2] > 0
