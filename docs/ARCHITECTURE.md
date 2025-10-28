# Architecture of the Automatic Dev Setup Suite

## 1. Overview

The Automatic Dev Setup suite is a collection of shell scripts designed to provision a macOS workstation for development. It automates the installation and configuration of a wide range of tools and applications, from Homebrew and shell enhancements to programming language runtimes and database systems.

## 2. Components

The suite is organized into several directories, each with a specific purpose:

- **`core/`**: This directory contains the main orchestration script (`00-automatic-dev-orchestrator.sh`) and the individual modules (`01-` to `10-`) that perform the actual setup tasks.
- **`lib/`**: This directory contains shared library scripts that provide common functions for logging, error handling, validation, and environment setup.
- **`operations_setup/`**: This directory contains wrapper scripts for re-running specific modules of the setup.
- **`operations_support/`**: This directory contains scripts for validation, repair, and troubleshooting.
- **`config/`**: This directory contains the main configuration file (`automatic-dev-config.env`), as well as the Brewfile and Python requirements files.
- **`docs/`**: This directory contains the documentation for the suite.
- **`templates/`**: This directory contains project templates that can be used to create new projects with a standardized structure.
- **`testing/`**: This directory contains the test suite for the project.
- **`tools/`**: This directory contains various helper tools and scripts.
- **`special_files/`**: This directory contains files for auditing and special purposes.

## 3. Execution Flow

The main entry point for the suite is the `install.sh` script. This script copies the suite to the user's home directory (`~/automatic_dev_setup`) and then executes the main orchestrator script (`core/00-automatic-dev-orchestrator.sh`).

The orchestrator script executes the individual modules in the `core` directory in a specific order. Each module is responsible for a specific part of the setup process.

The `operations_setup` and `operations_support` scripts can be used to re-run specific modules or to perform other maintenance tasks.

## 4. Configuration

The suite is configured through the `automatic-dev-config.env` file. This file contains a number of environment variables (prefixed with `ADS_`) that control the behavior of the scripts.

The `config` directory also contains the `Brewfile.automatic-dev` file, which lists the Homebrew packages to be installed, and the `requirements-automatic-dev.txt` and `constraints-automatic-dev.txt` files, which list the Python packages to be installed.

## 5. Dependencies

The scripts in the suite have a number of dependencies on each other and on the environment variables defined in `automatic-dev-config.env`. These dependencies are not explicitly documented in the code, which can make it difficult to understand the impact of changes.

A dependency graph of the `ADS_*` variables has been generated and is available in the `dependency-graph.dot` file. This file can be used to visualize the dependencies between the scripts and the configuration variables.
