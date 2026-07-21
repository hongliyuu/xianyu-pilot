import unittest

from scripts.production_preflight import _secret_file_permissions_are_safe, validate


class ProductionPreflightTests(unittest.TestCase):
    def test_root_is_rejected_as_application_database_user(self) -> None:
        report = validate({"MYSQL_APP_USER": "root"})

        self.assertIn(
            "MYSQL_APP_USER: must be a dedicated non-administrative database user",
            report.errors,
        )

    def test_secret_file_permissions_match_compose_mount_requirements(self) -> None:
        self.assertTrue(_secret_file_permissions_are_safe(0o600, 0o755))
        self.assertTrue(_secret_file_permissions_are_safe(0o644, 0o700))
        self.assertFalse(_secret_file_permissions_are_safe(0o644, 0o755))
        self.assertFalse(_secret_file_permissions_are_safe(0o664, 0o700))

    def test_missing_public_base_url_is_reported_as_warning(self) -> None:
        report = validate({})

        self.assertIn(
            "PUBLIC_BASE_URL: is not configured; external ingress verification "
            "remains the deployment owner's responsibility",
            report.warnings,
        )


if __name__ == "__main__":
    unittest.main()
