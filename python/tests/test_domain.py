from huutopussi_rl import Card, Rank, Suit
from huutopussi_rl.config import ExperimentConfig


def test_huutopussi_card_ranks_include_the_reduced_deck() -> None:
    assert len(Rank) == 9
    assert Card(Suit.SPADES, Rank.ACE).rank == Rank.ACE


def test_experiment_defaults_match_three_player_game() -> None:
    config = ExperimentConfig()
    assert config.players == 3
    assert config.action_size == 36
