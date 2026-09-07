"""
Escrix Verifier Sandbox
-----------------------
Runs task verification in an isolated Docker container.
Currently supports: python_unittest (MVP)

Called by the Escrix Verifier Node after executor submits a result.
Returns: { passed: bool, note: str, result_hash: str }
"""

import hashlib
import json
import subprocess
import tempfile
import textwrap
import time
from pathlib import Path


SUPPORTED_TASK_TYPES = ["python_unittest"]

# Hard limits (security + cost)
TIMEOUT_SECONDS = 10
MAX_OUTPUT_BYTES = 64 * 1024   # 64 KB
DOCKER_IMAGE     = "python:3.11-slim"
MEMORY_LIMIT     = "64m"
CPU_LIMIT        = "0.5"


def verify_task(task_spec: dict, result: dict) -> dict:
    """
    Main entry point for task verification.

    Args:
        task_spec: The original task specification (from IPFS / off-chain store)
        result:    The executor's submitted result

    Returns:
        {
            "passed":      bool,
            "note":        str,   # human-readable explanation
            "result_hash": str,   # keccak256-style hash of result for on-chain commit
        }
    """
    task_type = task_spec.get("type")
    if task_type not in SUPPORTED_TASK_TYPES:
        return _fail(f"Unsupported task type: {task_type}")

    if task_type == "python_unittest":
        return _verify_python_unittest(task_spec, result)

    return _fail("Unknown task type")


def _verify_python_unittest(spec: dict, result: dict) -> dict:
    """
    Verify a Python function implementation against unit tests.

    spec expects:
        function_signature: str  e.g. "def add(a: int, b: int) -> int"
        test_cases: list[str]    e.g. ["assert add(1, 2) == 3"]
        allowed_imports: list[str]  (optional, default [])

    result expects:
        implementation: str  the Python function code
    """
    implementation = result.get("implementation", "").strip()
    if not implementation:
        return _fail("No implementation provided")

    test_cases   = spec.get("test_cases", [])
    allowed_imports = spec.get("allowed_imports", [])

    if not test_cases:
        return _fail("No test cases in spec")

    # Build the test script
    import_lines = "\n".join(f"import {m}" for m in allowed_imports)
    test_lines   = "\n".join(f"    {t}" for t in test_cases)

    test_script = textwrap.dedent(f"""
        {import_lines}

        # --- Executor's implementation ---
        {implementation}

        # --- Test cases ---
        def run_tests():
        {test_lines if test_lines else "    pass"}

        run_tests()
        print("__ESCRIX_PASS__")
    """).strip()

    result_hash = _hash_result(result)

    # Run in Docker sandbox
    outcome = _run_in_docker(test_script)

    if outcome["error"]:
        return {
            "passed":      False,
            "note":        f"Execution error: {outcome['error'][:500]}",
            "result_hash": result_hash,
        }

    stdout = outcome["stdout"]
    if "__ESCRIX_PASS__" in stdout:
        return {
            "passed":      True,
            "note":        "All test cases passed",
            "result_hash": result_hash,
        }
    else:
        stderr = outcome.get("stderr", "")
        detail = (stderr or stdout)[:500]
        return {
            "passed":      False,
            "note":        f"Tests failed: {detail}",
            "result_hash": result_hash,
        }


def _run_in_docker(script: str) -> dict:
    """Run a Python script in an isolated Docker container."""
    with tempfile.TemporaryDirectory() as tmpdir:
        script_path = Path(tmpdir) / "test_script.py"
        script_path.write_text(script)

        cmd = [
            "docker", "run",
            "--rm",
            "--network", "none",           # no internet access
            "--memory", MEMORY_LIMIT,
            "--cpus",   CPU_LIMIT,
            "--read-only",                 # read-only filesystem
            "--tmpfs", "/tmp:size=16m",    # small writable /tmp
            "--security-opt", "no-new-privileges",
            "-v", f"{tmpdir}:/sandbox:ro",
            DOCKER_IMAGE,
            "python", "/sandbox/test_script.py"
        ]

        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=TIMEOUT_SECONDS
            )
            return {
                "stdout": proc.stdout[:MAX_OUTPUT_BYTES],
                "stderr": proc.stderr[:MAX_OUTPUT_BYTES],
                "error":  None if proc.returncode == 0 else proc.stderr[:500],
            }
        except subprocess.TimeoutExpired:
            return {"stdout": "", "stderr": "", "error": f"Timeout after {TIMEOUT_SECONDS}s"}
        except FileNotFoundError:
            return {"stdout": "", "stderr": "", "error": "Docker not available"}
        except Exception as e:
            return {"stdout": "", "stderr": "", "error": str(e)}


def _hash_result(result: dict) -> str:
    """Deterministic hash of the result dict (for on-chain commitment)."""
    canonical = json.dumps(result, sort_keys=True, ensure_ascii=True)
    return "0x" + hashlib.sha3_256(canonical.encode()).hexdigest()


def _fail(note: str) -> dict:
    return {"passed": False, "note": note, "result_hash": "0x" + "0" * 64}


# ── CLI for local testing ──────────────────────────────────────────────────────

if __name__ == "__main__":
    # Quick smoke test
    test_spec = {
        "type": "python_unittest",
        "function_signature": "def add(a: int, b: int) -> int",
        "test_cases": [
            "assert add(1, 2) == 3",
            "assert add(-1, 1) == 0",
            "assert add(0, 0) == 0",
        ],
    }

    good_result = {"implementation": "def add(a, b):\n    return a + b"}
    bad_result  = {"implementation": "def add(a, b):\n    return a - b"}

    print("=== Testing PASS case ===")
    r = verify_task(test_spec, good_result)
    print(json.dumps(r, indent=2))

    print("\n=== Testing FAIL case ===")
    r = verify_task(test_spec, bad_result)
    print(json.dumps(r, indent=2))
