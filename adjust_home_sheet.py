from pathlib import Path

path = Path("frontend/sodamrok/lib/features/home/presentation/home_screen.dart")
text = path.read_text(encoding="utf8")
old_container = "        return Container(\n          margin: EdgeInsets.only(top: topPadding),\n          padding: EdgeInsets.only(bottom: bottomPadding),"
new_container = "        return Container(\n          margin: EdgeInsets.fromLTRB(0, topPadding, 0, bottomPadding),"
if old_container not in text:
    raise SystemExit("container pattern not found")

text = text.replace(old_container, new_container, 1)
path.write_text(text, encoding="utf8")
