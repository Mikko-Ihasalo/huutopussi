# Huutopussi Python tools

This folder contains the Python-side foundation for reinforcement learning experiments and analysis of games played by the Godot project.

## Setup

From this directory, create a virtual environment and install the development set:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[all]"
```

Run the checks with:

```powershell
pytest
ruff check .
mypy src
```

## Layout

- `src/huutopussi_rl/domain.py`: typed cards, actions, and episode records.
- `src/huutopussi_rl/env.py`: Gymnasium environment boundary for a future Godot bridge.
- `src/huutopussi_rl/analysis.py`: JSONL episode loading and summary statistics.
- `src/huutopussi_rl/config.py`: experiment configuration.
- `tests/`: fast contract tests for the Python layer.
- `data/`: local recordings and derived datasets; large files should stay untracked.
- `notebooks/`: exploratory analysis notebooks.
- `scripts/`: repeatable data collection and training entry points.

The environment adapter deliberately does not duplicate the Godot rules. A bridge should serialize observations and actions using the domain types and delegate rule enforcement to the game engine.

## Suggested libraries

- **Gymnasium**: standard environment API for RL algorithms.
- **Stable-Baselines3 + PyTorch**: practical baseline algorithms such as PPO and DQN.
- **NumPy**: compact numerical observations and action masks.
- **pandas + PyArrow**: tabular episode summaries and efficient Parquet datasets.
- **Matplotlib + Seaborn**: reproducible experiment plots.
- **pytest, Ruff, and mypy**: tests, linting, and type checking.

The Godot bridge itself can start as a local process adapter, TCP/WebSocket service, or file-based replay importer. The choice depends on whether training needs live interaction or only recorded games.
