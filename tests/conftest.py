"""
Pytest configuration and fixtures for integration tests.
"""

import time
from typing import Generator

import docker
import pytest
import trino


@pytest.fixture(scope="session")
def docker_client() -> Generator[docker.DockerClient, None, None]:
    """Provide Docker client for testing."""
    client = docker.from_env()
    yield client
    client.close()


@pytest.fixture(scope="session")
def demo_stack_running(docker_client: docker.DockerClient) -> bool:
    """Check if demo stack is running."""
    required_containers = [
        "nifi-1",
        "kafka",
        "trino",
        "superset",
        "jupyter",
        "minio",
        "postgres",
    ]

    try:
        containers = docker_client.containers.list()
        running_names = [c.name for c in containers]

        all_running = all(name in running_names for name in required_containers)

        if not all_running:
            missing = [
                name for name in required_containers if name not in running_names
            ]
            pytest.skip(
                f"Demo stack not fully running. Missing: {', '.join(missing)}"
            )

        return True
    except Exception as e:
        pytest.skip(f"Cannot check Docker containers: {e}")


@pytest.fixture(scope="session")
def trino_connection(demo_stack_running) -> Generator[trino.dbapi.Connection, None, None]:
    """Provide Trino connection for testing."""
    conn = trino.dbapi.connect(
        host="localhost",
        port=8080,
        catalog="iceberg",
        schema="lakehouse",
    )
    yield conn
    conn.close()


@pytest.fixture(scope="session")
def wait_for_trino_ready(trino_connection) -> None:
    """Wait for Trino to be fully ready."""
    max_retries = 30
    retry_interval = 2

    for i in range(max_retries):
        try:
            cursor = trino_connection.cursor()
            cursor.execute("SELECT 1")
            cursor.fetchall()
            cursor.close()
            return
        except Exception:
            if i == max_retries - 1:
                pytest.fail("Trino did not become ready in time")
            time.sleep(retry_interval)


@pytest.fixture
def sample_query() -> str:
    """Provide a sample query for testing."""
    return "SELECT COUNT(*) as count FROM orders LIMIT 1"
