extends RefCounted
## One instance belongs to one campaign, including in-flight cargo and its purchase cost.
const CONDITION_NAMES := {"peace": "평시", "war": "전쟁", "raid": "약탈", "siege": "포위"}
const OUTPUT_FACTOR := {"peace": 1.0, "war": 0.65, "raid": 0.25, "siege": 0.1}
const ROAD_FACTOR := {"peace": 1.0, "war": 0.65, "raid": 0.5, "siege": 0.0}
const DISTANCE_PER_HOUR := 65.0
const LOAD_LIMIT := 36
var rng := RandomNumberGenerator.new()
var goods: Dictionary
var markets := {}
var caravans: Array[Dictionary] = []
var roads := {}
var hour := 0
var trade_experience := 0

func initialize(cities: Array, catalog: Dictionary, entries: Dictionary, navigation: WorldNavigation) -> void:
	goods = catalog
	var assortment: Array[int] = []
	for city: Dictionary in cities:
		for raw_id in city.products:
			var id := int(raw_id)
			if not assortment.has(id): assortment.append(id)
	assortment.sort()
	for city: Dictionary in cities:
		var products: Array[int] = []
		products.assign(city.products)
		var order := products.duplicate()
		for id in assortment:
			if not order.has(id): order.append(id)
		var market := {"name": city.name, "population": city.population, "prosperity": city.prosperity,
			"order": order, "stock": {}, "output": {}, "demand": {}, "unmet": {},
			"condition": "peace", "days_left": 0}
		for id: int in goods:
			var local := products.has(id)
			market.stock[id] = rng.randi_range(100, 200) if local else (rng.randi_range(1, 20) if id in assortment else 0)
			market.output[id] = 10 + (id + int(city.population / 100.0)) % 16 if local else 0
			# Expensive goods turn over less frequently than everyday staples.
			market.demand[id] = maxi(1, roundi(city.population / 1800.0 * city.prosperity / sqrt(maxf(1, goods[id].price / 6.0))))
			market.unmet[id] = 0
		markets[city.id] = market
		roads[city.id] = {}
		caravans.append({"city": city.id, "to": "", "distance": 0.0, "speed": 0.0,
			"cargo": {}, "cash": 2500, "position": entries[city.id], "depart_hour": caravans.size() + 1})
	for origin: String in markets:
		for dest: String in markets:
			if origin == dest or roads[origin].has(dest): continue
			var points := navigation.route(entries[origin], entries[dest])
			if points.is_empty(): continue
			points.insert(0, entries[origin])
			roads[origin][dest] = road_curve(points)
			points.reverse()
			roads[dest][origin] = road_curve(points)

func road_curve(points: PackedVector2Array) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = 1.0
	for point in points: curve.add_point(point)
	return curve

func skill() -> int:
	return mini(10, floori(trade_experience / 20.0))

func quote(city: String, id: int, buying: bool, level: int) -> int:
	var market: Dictionary = markets[city]
	var demand := float(market.demand[id])
	var reserve := 12.0 + 6.0 * demand + float(market.unmet[id])
	if market.condition != "peace": reserve *= 1.25
	# The last unit bought and the first sold back use the same marginal stock level.
	var stock := maxf(0.0, float(market.stock[id]) + (-0.5 if buying else 0.5))
	var value := float(goods[id].price) * (0.40 + 2.35 * reserve / (reserve + stock))
	var margin := 0.18 - 0.014 * clampi(level, 0, 10)
	if buying: return maxi(2, ceili(value * (1 + margin)))
	return maxi(1, floori(value * (1 - margin)))

func change_stock(city: String, id: int, amount: int) -> void:
	if amount > 0 and not markets[city].order.has(id): markets[city].order.append(id)
	var stock: Dictionary = markets[city].stock
	stock[id] = int(stock[id]) + amount

func set_condition(city: String, condition: String, days: int) -> void:
	var market: Dictionary = markets[city]
	market.condition = condition
	market.days_left = days
	if condition == "raid":
		for id: int in market.order:
			market.stock[id] = floori(market.stock[id] * 0.8)

func advance_day() -> void:
	for market: Dictionary in markets.values():
		if market.days_left > 0:
			market.days_left -= 1
			if market.days_left == 0: market.condition = "peace"
	# Temporary disruptions stand in for campaign war events until those systems exist.
	if rng.randf() < 0.28:
		var city: String = markets.keys()[rng.randi_range(0, markets.size() - 1)]
		if markets[city].condition == "peace":
			set_condition(city, ["war", "raid", "siege"][rng.randi_range(0, 2)], rng.randi_range(2, 4))
	for market: Dictionary in markets.values():
		for id: int in market.order:
			var stock := int(market.stock[id])
			var output := float(market.output[id]) * float(OUTPUT_FACTOR[market.condition])
			var produced := roundi(output * clampf(1.25 - stock / 400.0, 0.0, 1.0))
			var demand := int(market.demand[id])
			var needed := demand + mini(demand, market.unmet[id])
			var consumed := mini(stock + produced, needed)
			market.stock[id] = stock + produced - consumed
			market.unmet[id] = clampi(market.unmet[id] + demand - consumed, 0, 4 * demand)

func advance_to(campaign_hours: float) -> void:
	while hour < floori(campaign_hours):
		hour += 1
		for caravan in caravans:
			caravan.distance += caravan.speed
		if hour % 24 == 0: advance_day()
		for caravan in caravans:
			tick_caravan(caravan)

func tick_caravan(caravan: Dictionary) -> void:
	var origin: String = caravan.city
	var dest: String = caravan.to
	if dest.is_empty():
		if hour >= caravan.depart_hour and markets[origin].condition != "siege":
			dispatch(caravan)
		return
	var road: Curve2D = roads[origin][dest]
	caravan.distance = minf(caravan.distance, road.get_baked_length())
	caravan.speed = travel_speed(origin, dest)
	if caravan.distance < road.get_baked_length() or markets[dest].condition == "siege": return
	for id: int in caravan.cargo:
		for unit in int(caravan.cargo[id]):
			caravan.cash += quote(dest, id, false, 8)
			change_stock(dest, id, 1)
	caravan.position = road.sample_baked(road.get_baked_length())
	caravan.cargo.clear()
	caravan.city = dest
	caravan.to = ""
	caravan.speed = 0.0
	caravan.distance = 0.0
	caravan.depart_hour = hour + 1

func travel_speed(origin: String, dest: String) -> float:
	return DISTANCE_PER_HOUR * minf(ROAD_FACTOR[markets[origin].condition], ROAD_FACTOR[markets[dest].condition])

func dispatch(caravan: Dictionary) -> void:
	var origin: String = caravan.city
	var best_score := 0.0
	var destination := ""
	var manifest: Array = []
	for dest: String in roads[origin]:
		if markets[dest].condition == "siege": continue
		var offers := []
		var score := 0.0
		for id: int in markets[origin].order:
			var available := int(markets[origin].stock[id])
			var cost := quote(origin, id, true, 8)
			if available <= 0 or cost > caravan.cash: continue
			var gain := quote(dest, id, false, 8) - cost
			if gain <= 0: continue
			var return_rate := float(gain) / cost
			offers.append({"id": id, "return_rate": return_rate})
			score += return_rate * mini(available, 6)
		var road: Curve2D = roads[origin][dest]
		score /= 1.0 + road.get_baked_length() / travel_speed(origin, dest)
		if score > best_score:
			best_score = score
			destination = dest
			manifest = offers
	if destination.is_empty(): return
	manifest.sort_custom(func(a, b): return a.return_rate > b.return_rate)
	var loaded := 0
	for offer: Dictionary in manifest:
		var id := int(offer.id)
		var count := 0
		for unit in mini(8, mini(markets[origin].stock[id], LOAD_LIMIT - loaded)):
			var cost := quote(origin, id, true, 8)
			if cost > caravan.cash or cost >= quote(destination, id, false, 8): break
			change_stock(origin, id, -1)
			caravan.cash -= cost
			count += 1
			loaded += 1
		if count > 0: caravan.cargo[id] = count
		if loaded >= LOAD_LIMIT: break
	caravan.to = destination
	caravan.distance = 0.0
	caravan.speed = travel_speed(origin, destination)

func caravan_position(caravan: Dictionary, fraction: float) -> Vector2:
	if caravan.to == "": return caravan.position
	var road: Curve2D = roads[caravan.city][caravan.to]
	return road.sample_baked(minf(road.get_baked_length(), caravan.distance + fraction * caravan.speed))
