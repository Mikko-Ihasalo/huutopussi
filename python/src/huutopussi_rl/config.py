"""Configuration shared by training and data collection scripts."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ExperimentConfig:
    """Reproducible defaults for an experiment run."""

    seed: int = 0
    players: int = 3
    observation_size: int = 0
    action_size: int = 36
    output_dir: str = "data/runs"
