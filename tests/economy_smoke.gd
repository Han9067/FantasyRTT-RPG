extends SceneTree

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
		var products: Array[int] = []
		products.assign(city.products)
		for id: int in market.order:
			var count := int(market.stock[id])
			if products.has(id): assert(count >= 100 and count <= 200)
			else: assert(count >= 1 and count <= 20)
			assert(union.has(id))
	var source := "city_01"
	var dest := "city_02"
	var silver := 5024
	var price := econ.quote(source, silver, true)
	assert(price < econ.quote(dest, silver, false))
	econ.change_stock(source, silver, -65)
	assert(econ.quote(source, silver, true) > price)
	econ.change_stock(source, silver, 65)
	assert(econ.quote(source, silver, true) == price)
	assert(econ.quote(source, silver, false) < price)
	var saved_markets := econ.markets.duplicate(true)
	var elapsed := map.clock.elapsed
	map.clock.set_speed(4)
	map._physics_process(map.clock.SECONDS_PER_DAY * 30)
	assert(map.clock.elapsed > elapsed and econ.markets == saved_markets)
	assert(econ.quote(source, silver, true) == price)
	game.enter_battle_from_world()
	game.show_world()
	assert(game.world.economy == econ and econ.markets == saved_markets)
	game.start_journey()
	assert(game.world.economy != econ)
	print("PASS: specialty and import stock, town prices and spread, stock-driven repricing, time-independent markets and campaign continuity")
	quit()
