import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class DeploymentContractTests(unittest.TestCase):
    def test_docker_resources_use_repository_name(self) -> None:
        deploy_script = (ROOT / "deploy.sh").read_text(encoding="utf-8")
        compose = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
        workflow = (
            ROOT / ".github" / "workflows" / "docker-publish.yml"
        ).read_text(encoding="utf-8")

        self.assertIn('PROJECT_NAME="xianyu-pilot"', deploy_script)
        self.assertIn("name: xianyu-pilot", compose)
        for component in ("api", "web", "crawler"):
            image_name = f"xianyu-pilot-{component}"
            self.assertIn(image_name, deploy_script)
            self.assertIn(image_name, compose)
        self.assertIn("xianyu-pilot-${{ matrix.component }}", workflow)

    def test_uninstall_is_project_scoped_and_confirmed(self) -> None:
        deploy_script = (ROOT / "deploy.sh").read_text(encoding="utf-8")

        self.assertIn("command_uninstall()", deploy_script)
        self.assertIn("com.docker.compose.project=$project", deploy_script)
        self.assertIn('[ -t 0 ]', deploy_script)
        self.assertNotIn("docker system prune", deploy_script)
        self.assertNotIn("LEGACY_PROJECT_NAME", deploy_script)


if __name__ == "__main__":
    unittest.main()
