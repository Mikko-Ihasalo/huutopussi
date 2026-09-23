"""Gymnasium boundary for connecting RL code to the Godot game."""

from typing import Any

import gymnasium as gym
import numpy as np
from numpy.typing import NDArray


class GodotHuutopussiEnv(gym.Env[NDArray[np.float32], int]):
    """Skeleton environment whose rules and state transitions stay in Godot."""

    def __init__(self, observation_size: int, action_size: int) -> None:
        super().__init__()
        self.observation_space = gym.spaces.Box(
            low=-np.inf, high=np.inf, shape=(observation_size,), dtype=np.float32
        )
        self.action_space = gym.spaces.Discrete(action_size)
