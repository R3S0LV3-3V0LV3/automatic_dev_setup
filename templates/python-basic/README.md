# Python Basic Project Starter

This starter mirrors GitHub’s recommended layout for small-to-medium Python applications. It balances clarity for newcomers with a structure that scales as your project grows.

## Structure
```
python-basic/
├── README.md
├── .gitignore
├── requirements.txt
├── src/
│   └── main.py
└── tests/
    └── test_sample.py
```

## Getting Started
1. **Create a virtual environment**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```
2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```
3. **Run the sample app**
   ```bash
   python -m src.main
   ```
4. **Execute tests**
   ```bash
   pytest
   ```

## Recommended Practices
- Keep business logic inside `src/` and tests inside `tests/`.
- Pin exact dependency versions in `requirements.txt` or migrate to `pyproject.toml` once the project grows.
- Add additional tooling (formatters, linters, CI workflows) as the project matures.

For more guidance, review the project formatting notes in `~/coding_environment/__project-formatting.txt`.
