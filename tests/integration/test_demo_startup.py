"""
Integration tests for demo startup and service health.
"""

import time

import docker
import pytest
import requests


class TestDemoStartup:
    """Test demo.sh startup and service health."""

    def test_docker_running(self, docker_client: docker.DockerClient):
        """Test Docker daemon is running."""
        assert docker_client.ping(), "Docker daemon is not responding"

    def test_required_containers_exist(self, docker_client: docker.DockerClient):
        """Test all required containers exist."""
        required = [
            "zookeeper",
            "kafka",
            "schema-registry",
            "postgres",
            "minio",
            "redis",
            "nifi-1",
            "trino",
            "superset",
            "jupyter",
        ]

        containers = docker_client.containers.list(all=True)
        container_names = [c.name for c in containers]

        for name in required:
            assert name in container_names, f"Container {name} not found"

    def test_containers_running(self, docker_client: docker.DockerClient):
        """Test all containers are in running state."""
        required = [
            "zookeeper",
            "kafka",
            "postgres",
            "minio",
            "redis",
            "nifi-1",
            "trino",
            "superset",
            "jupyter",
        ]

        containers = docker_client.containers.list()
        running_names = [c.name for c in containers]

        for name in required:
            assert name in running_names, f"Container {name} is not running"

    def test_containers_healthy(self, docker_client: docker.DockerClient):
        """Test containers with health checks are healthy."""
        containers_with_health = [
            "postgres",
            "minio",
            "nifi-1",
            "trino",
            "superset",
            "jupyter",
        ]

        for name in containers_with_health:
            container = docker_client.containers.get(name)
            health = container.attrs.get("State", {}).get("Health", {})

            # If container has health check, verify it's healthy
            if health:
                status = health.get("Status")
                assert (
                    status == "healthy"
                ), f"Container {name} health status is {status}"

    def test_nifi_ui_accessible(self):
        """Test NiFi UI is accessible."""
        response = requests.get(
            "https://localhost:8443/nifi/",
            verify=False,  # Self-signed cert
            timeout=10,
        )
        assert response.status_code in [
            200,
            302,
        ], f"NiFi UI returned status {response.status_code}"

    def test_superset_ui_accessible(self):
        """Test Superset UI is accessible."""
        response = requests.get("http://localhost:8088/health", timeout=10)
        assert (
            response.status_code == 200
        ), f"Superset health check returned {response.status_code}"

    def test_jupyter_ui_accessible(self):
        """Test Jupyter UI is accessible."""
        response = requests.get("http://localhost:8888/", timeout=10)
        assert response.status_code in [
            200,
            302,
        ], f"Jupyter UI returned {response.status_code}"

    def test_trino_ui_accessible(self):
        """Test Trino UI is accessible."""
        response = requests.get("http://localhost:8080/ui/", timeout=10)
        assert (
            response.status_code == 200
        ), f"Trino UI returned {response.status_code}"

    def test_minio_console_accessible(self):
        """Test MinIO console is accessible."""
        response = requests.get("http://localhost:9001/", timeout=10)
        assert response.status_code in [
            200,
            302,
        ], f"MinIO console returned {response.status_code}"

    def test_trino_info_endpoint(self):
        """Test Trino info endpoint returns valid JSON."""
        response = requests.get("http://localhost:8080/v1/info", timeout=10)
        assert response.status_code == 200
        data = response.json()
        assert "nodeVersion" in data
        assert "starting" in data
        assert data["starting"] is False, "Trino is still starting"

    def test_container_resource_usage(self, docker_client: docker.DockerClient):
        """Test containers are not using excessive resources."""
        containers = docker_client.containers.list()

        for container in containers:
            stats = container.stats(stream=False)

            # Check memory usage (should be under configured limit)
            mem_usage = stats["memory_stats"].get("usage", 0)
            mem_limit = stats["memory_stats"].get("limit", 1)
            mem_percent = (mem_usage / mem_limit) * 100 if mem_limit > 0 else 0

            # Warning if over 90% memory
            assert (
                mem_percent < 95
            ), f"Container {container.name} using {mem_percent:.1f}% memory"
