import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DELIVERY_ROUTE = ROOT / "apps" / "api" / "app" / "api" / "v1" / "routes" / "delivery_workflow_compat.py"
ACCOUNT_SCHEMA = ROOT / "apps" / "api" / "app" / "schemas" / "account.py"
ACCOUNT_ROUTE = ROOT / "apps" / "api" / "app" / "api" / "v1" / "routes" / "account.py"
RESTFUL_ROUTE = ROOT / "apps" / "api" / "app" / "api" / "v1" / "routes" / "restful.py"
FRONTEND_COMPAT_ROUTE = ROOT / "apps" / "api" / "app" / "api" / "v1" / "routes" / "frontend_compat.py"


class DeliveryRecordQueryTests(unittest.TestCase):
    def test_delivery_record_queries_use_the_single_account_name_contract(self) -> None:
        source = DELIVERY_ROUTE.read_text(encoding="utf-8")

        self.assertNotIn("acc.display_name", source)
        self.assertNotIn("seller_display_name", source)
        self.assertEqual(source.count("acc.nickname AS seller_name"), 2)


class AccountNameContractTests(unittest.TestCase):
    def test_account_responses_do_not_alias_nickname_as_display_name(self) -> None:
        sources = [
            ACCOUNT_SCHEMA.read_text(encoding="utf-8"),
            ACCOUNT_ROUTE.read_text(encoding="utf-8"),
            RESTFUL_ROUTE.read_text(encoding="utf-8"),
            FRONTEND_COMPAT_ROUTE.read_text(encoding="utf-8"),
            DELIVERY_ROUTE.read_text(encoding="utf-8"),
        ]
        source = "\n".join(sources)

        self.assertNotIn("display_name=account.nickname", source)
        self.assertNotIn('"display_name": account.nickname', source)
        self.assertNotIn('"displayName": a.nickname', source)
        self.assertNotIn('"displayName": account.nickname', source)
        self.assertNotIn('"displayName": row.get("account_nickname")', source)


if __name__ == "__main__":
    unittest.main()
