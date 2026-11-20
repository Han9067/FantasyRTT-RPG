"""Pack the original 32px trade icons into the slots referenced by the sheet snapshot."""
import json
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
output = root / "assets/world"
catalog = json.loads((output / "trade_catalog.json").read_text())
goods = catalog["goods"]
ids = {item["id"] for item in goods}
assert len(ids) == len(goods)
assert all(set(city["products"]) <= ids for city in catalog["cities"].values())
assert {item["slot"] for item in goods} == set(range(len(goods)))
atlas = Image.new("RGBA", (8 * 32, ((len(goods) + 7) // 8) * 32))
for item in goods:
    with Image.open(root / "art/medieval/sprites/Item" / (item["image"] + ".png")) as icon:
        assert icon.size == (32, 32), item["name"]
        x, y = item["slot"] % 8, item["slot"] // 8
        atlas.paste(icon.convert("RGBA"), (x * 32, y * 32))
atlas.save(output / "trade_icons.png")
