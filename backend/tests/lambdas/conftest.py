import importlib.util
from pathlib import Path

import pytest

LAMBDAS_DIR = Path(__file__).parent.parent.parent / "lambdas"


class FakeLambdaContext:
    function_name = "test-fn"
    memory_limit_in_mb = 128
    invoked_function_arn = "arn:aws:lambda:ap-southeast-1:123456789012:function:test-fn"
    aws_request_id = "test-request-id"


def load_handler_module(module_name: str, dir_name: str):
    """Load a Lambda handler.py as a uniquely-named module so multiple
    handlers (all literally named 'handler.py') can coexist in one test
    session without clobbering each other in sys.modules."""
    spec = importlib.util.spec_from_file_location(
        module_name, LAMBDAS_DIR / dir_name / "handler.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def fake_context():
    return FakeLambdaContext()
