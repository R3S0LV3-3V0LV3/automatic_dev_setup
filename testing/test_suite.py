import os
import subprocess

def test_source_config():
    """Tests that the automatic-dev-config.env file can be sourced without errors."""
    source_cmd = f"source {os.environ['ADS_SUITE_ROOT']}/automatic-dev-config.env"
    result = subprocess.run(["bash", "-c", source_cmd], capture_output=True)
    assert result.returncode == 0, f"Failed to source automatic-dev-config.env: {result.stderr.decode()}"
