import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_script(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def test_latest_samples_plan_check_fails_gracefully_without_db_env() -> None:
    proc = _run_script('checks/check_v4_latest_samples_query_plan.py')
    assert proc.returncode == 2
    assert 'Backend DB configuration is incomplete' in proc.stdout
    assert 'Missing required DB env vars' in proc.stdout


def test_kpi_benchmark_check_fails_gracefully_without_db_env() -> None:
    proc = _run_script('checks/check_v4_kpi_query_paths_benchmark.py', '--tags', 'spp,rpm')
    assert proc.returncode == 2
    assert 'Backend DB configuration is incomplete' in proc.stdout
    assert 'Missing required DB env vars' in proc.stdout
