extends RefCounted
## City stock is rolled once per campaign and changes when the player trades.
const REFERENCE_STOCK := 30.0
const TRADE_MARGIN := 0.18

var goods: Dictionary
var markets := {}

func initialize(cities: Array, catalog: Dictionary) -> void:
	goods = catalog
	var assortment: Array[int] = []
	for city: Dictionary in cities:
		for raw_id in city.products:
			var id := int(raw_id)
			if not assortment.has(id): assortment.append(id)
	assortment.sort()
	var rng := RandomNumberGenerator.new()
	for city: Dictionary in cities:
		var order: Array[int] = []
		order.assign(city.products)
		var stock := {}
		for id in order:
			stock[id] = rng.randi_range(100, 200)
		for id in assortment:
			if stock.has(id): continue
			order.append(id)
			stock[id] = rng.randi_range(1, 20)
		markets[city.id] = {"name": city.name, "order": order, "stock": stock}

func quote(city: String, id: int, buying: bool) -> int:
	# Buying a unit and selling it back use the same stock midpoint.
	var count := int(markets[city].stock.get(id, 0))
	var stock := maxf(0.0, count + (-0.5 if buying else 0.5))
	var value := float(goods[id].price) * (0.40 + 2.35 * REFERENCE_STOCK / (REFERENCE_STOCK + stock))
	if buying: return maxi(2, ceili(value * (1 + TRADE_MARGIN)))
	return maxi(1, floori(value * (1 - TRADE_MARGIN)))

func change_stock(city: String, id: int, amount: int) -> void:
	var market: Dictionary = markets[city]
	if not market.stock.has(id): market.order.append(id)
	market.stock[id] = int(market.stock.get(id, 0)) + amount
