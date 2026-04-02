# Container Notes

This image is a convenience environment for building the pinned stack and running Cmdenv experiments.

What it includes:

- Linux build prerequisites for OMNeT++, INET, Simu5G, Veins, and SUMO
- Python and `matplotlib` for KPI export and plotting
- a non-root `vscode` user for devcontainer workflows

What it does not guarantee:

- a validated native Qtenv GUI path inside the container
- exact SUMO `1.22.0` pin on every host mirror or package repository

Recommended use:

1. Open the repo in the included devcontainer.
2. Run `./setup.sh`.
3. Run `./verify_env.sh`.
4. Run `./build_all.sh`.
5. Run `./run_minimal.sh --cmdenv` or `./run_suite.sh --suite quick`.

If you need Qtenv from the container, forward X11 or Wayland from the host and treat it as an advanced, host-specific setup.
