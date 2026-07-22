import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API_DIR = ROOT / "apps" / "api"


class DashboardSchemaMigrationTests(unittest.TestCase):
    def test_legacy_message_compatibility_migration_creates_the_required_table(self) -> None:
        migration = API_DIR / "migrations" / "031_dashboard_delivery_schema_compatibility.sql"
        source = migration.read_text(encoding="utf-8")

        self.assertTrue(migration.is_file())
        self.assertIn("CREATE TABLE IF NOT EXISTS `xianyu_message`", source)
        self.assertNotIn("DROP TABLE", source)
        for column in ("account_id", "session_id", "is_auto_reply", "created_time"):
            self.assertIn(f"`{column}`", source)

    def test_dashboard_uses_authoritative_message_and_ai_reply_tables(self) -> None:
        dashboard = (API_DIR / "app" / "api" / "v1" / "routes" / "dashboard.py").read_text(
            encoding="utf-8"
        )

        self.assertIn("XianyuChatMessage", dashboard)
        self.assertIn("AiAutoReplyAttempt", dashboard)
        self.assertNotIn("XianyuMessage", dashboard)


if __name__ == "__main__":
    unittest.main()
