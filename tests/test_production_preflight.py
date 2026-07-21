import unittest

from scripts.production_preflight import validate


class ProductionPreflightTests(unittest.TestCase):
    def test_missing_public_base_url_is_reported_as_warning(self) -> None:
        report = validate({})

        self.assertIn(
            "PUBLIC_BASE_URL: is not configured; external ingress verification "
            "remains the deployment owner's responsibility",
            report.warnings,
        )


if __name__ == "__main__":
    unittest.main()
