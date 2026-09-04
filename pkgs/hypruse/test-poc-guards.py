"""Regression checks for the live-test preconditions; never contacts the desktop."""
import ast
import copy
import unittest
from pathlib import Path


class Guards(unittest.TestCase):
    def setUp(self):
        source = ast.parse(Path(__file__).with_name("poc-client.py").read_text())
        function = next(n for n in source.body if isinstance(n, ast.FunctionDef) and n.name == "verify")
        self.expected = {"address": "0x123", "pid": 100, "class": "local.hypruse.PocA",
                         "title": "Hypruse Test A", "at": [20, 20], "size": [600, 400], "monitor": 0}
        self.client = {**copy.deepcopy(self.expected), "workspace": {"id": -99, "name": "special:hypruse-poc"},
                       "mapped": True, "hidden": False}
        self.active = "0x123"
        scope = {"windows": {"A": self.expected}, "query": self.query}
        # Operational checks must also survive PYTHONOPTIMIZE / python -O.
        exec(compile(ast.Module(body=[function], type_ignores=[]), "guard", "exec", optimize=2), scope)
        self.verify = scope["verify"]

    def query(self, name):
        return {"clients": [self.client], "activewindow": {"address": self.active},
                "monitors": [{"id": 0, "specialWorkspace": {"id": -99}}]}[name]

    def test_expected_fixture(self):
        self.verify("A", focused=True)

    def test_reused_address_rejected(self):
        self.client["pid"] = 999
        with self.assertRaises(RuntimeError):
            self.verify("A", focused=True)

    def test_changed_geometry_rejected(self):
        self.client["at"] = [-4000, 100]
        with self.assertRaises(RuntimeError):
            self.verify("A", focused=True)

    def test_changed_monitor_rejected(self):
        self.client["monitor"] = 1
        with self.assertRaises(RuntimeError):
            self.verify("A", focused=True)

    def test_focus_theft_rejected(self):
        self.active = "0x999"
        with self.assertRaises(RuntimeError):
            self.verify("A", focused=True)

    def test_hidden_workspace_rejected(self):
        self.client["workspace"]["id"] = -98
        with self.assertRaises(RuntimeError):
            self.verify("A", focused=True)


if __name__ == "__main__":
    unittest.main()
