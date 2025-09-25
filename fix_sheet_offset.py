from pathlib import Path

path = Path("frontend/sodamrok/lib/features/home/presentation/home_screen.dart")
text = path.read_text(encoding="utf8")
old = "    return DraggableScrollableSheet(\n      initialChildSize: 0.2,\n      minChildSize: 0.2,\n      maxChildSize: 0.9,\n      snap: true,\n      builder: (context, controller) {\n        final topPadding = MediaQuery.of(context).padding.top + 64;\n        return Container(\n          margin: EdgeInsets.only(top: topPadding),\n          decoration: const BoxDecoration(\n            color: Colors.white,\n            border: Border(\n              top: BorderSide(color: Color(0xFFE0D8CF), width: 1),\n            ),\n          ),\n          child: ListView.separated(\n"
new = "    return DraggableScrollableSheet(\n      initialChildSize: 0.2,\n      minChildSize: 0.2,\n      maxChildSize: 0.95,\n      snap: true,\n      builder: (context, controller) {\n        final topPadding = MediaQuery.of(context).padding.top + 64;\n        return Container(\n          margin: EdgeInsets.only(top: topPadding, bottom: 16),\n          decoration: const BoxDecoration(\n            color: Colors.white,\n            border: Border(\n              top: BorderSide(color: Color(0xFFE0D8CF), width: 1),\n            ),\n          ),\n          child: ListView.separated(\n"
if old not in text:
    raise SystemExit("pattern not found")
path.write_text(text.replace(old, new, 1), encoding="utf8")
