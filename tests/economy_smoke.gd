extends SceneTree
const Economy = preload("res://scripts/campaign_economy.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.show_world()
	var map: WorldMap = game.world
	map.set_physics_process(false)
	var econ := map.economy
	var union := {}
	for city: Dictionary in map.cities:
		for id in city.products: union[int(id)] = true
	for city: Dictionary in map.cities:
		var market: Dictionary = econ.markets[city.id]
		assert(market.order.size() == union.size())
		for id: int in market.order:
			var count := int(market.stock[id])
			if market.output[id] > 0: assert(count >= 100 and count <= 200)
			else: assert(count >= 1 and count <= 20)
			assert(union.has(id) and market.demand[id] > 0)
	var source := "city_01"
	var dest := "city_02"
	var silver := 5024
	var price := econ.quote(source, silver, true, 0)
	assert(price < econ.quote(dest, silver, false, 0))
	econ.change_stock(source, silver, -65)
	assert(econ.quote(source, silver, true, 0) > price)
	econ.change_stock(source, silver, 65)
	assert(econ.quote(source, silver, true, 0) == price)
	assert(econ.quote(source, silver, true, 10) < price)
	assert(econ.quote(source, silver, false, 10) > econ.quote(source, silver, false, 0))
	var caravan := econ.caravans[0]
	var stock_before: Dictionary = econ.markets[source].stock.duplicate()
	econ.dispatch(caravan)
	assert(caravan.to != "" and not caravan.cargo.is_empty())
	dest = caravan.to
	var cargo: Dictionary = caravan.cargo.duplicate()
	var dest_before: Dictionary = econ.markets[dest].stock.duplicate()
	for id: int in cargo:
		assert(econ.markets[source].stock[id] == stock_before[id] - cargo[id])
	var road: Curve2D = econ.roads[source][dest]
	assert(road.get_baked_length() > 0)
	for step in 12:
		caravan.distance = road.get_baked_length() * step / 12.0
		var pos := econ.caravan_position(caravan, 0.0)
		assert(map.navigation.open_cell(map.navigation.cell_at(pos)))
	caravan.distance = road.get_baked_length()
	econ.set_condition(dest, "siege", 3)
	econ.tick_caravan(caravan)
	assert(caravan.cargo == cargo and econ.markets[dest].stock == dest_before)
	econ.set_condition(dest, "peace", 0)
	econ.tick_caravan(caravan)
	assert(caravan.city == dest and caravan.cargo.is_empty())
	for id: int in cargo: assert(econ.markets[dest].stock[id] == dest_before[id] + cargo[id])
	var market: Dictionary = econ.markets[source]
	econ.set_condition(source, "raid", 2)
	assert(econ.travel_speed(source, dest) < econ.DISTANCE_PER_HOUR)
	var stocks: Dictionary = market.stock.duplicate()
	econ.advance_day()
	var imported := 5005
	assert(market.stock[imported] == maxi(0, stocks[imported] - market.demand[imported]))
	assert(market.stock[silver] >= 0 and market.days_left == 1)
	var initial_hour := econ.hour
	map.clock.set_speed(0)
	map._physics_process(15)
	assert(econ.hour == initial_hour)
	map.clock.set_speed(4)
	map._physics_process(30)
	assert(econ.hour == initial_hour + 24)
	var saved_stock: Dictionary = market.stock.duplicate()
	game.enter_battle_from_world()
	game.show_world()
	assert(game.world.economy == econ and econ.markets[source].stock == saved_stock)
	game.start_journey()
	assert(game.world.economy != econ and game.world.economy.hour == 0)
	print("PASS: campaign stock ranges, specialty arbitrage, marginal quotes and skill, routed cargo conservation, siege, recovery, daily consumption, time controls and campaign continuity")
	quit()
