extends Node3D

@export var interior_root: Node3D = null

var TABLE_TOP_Y := -0.74636995792389
var BOOK_HEIGHT := 3.8
var RANDOM_OFFSET := 0.15
var MAX_BOOKS_PER_ROOM := 2
var SECOND_BOOK_PROB := 0.2  # 20% chance to allow 2nd book in same room

# Offset for long tables
var LONG_TABLE_BOOK_OFFSET := 2.26

var rooms := [
	["Table", "Table2", "Table29", "Table30", "Table31"],  # Room A
	["Table3", "Table4", "Table5", "Table6", "Table7"],    # Room B
	["Table9", "Table10", "Table11"],                       # Room C
	["Table12", "Table13", "Table14", "Table15"],          # Room D
	["Table16", "Table17", "Table18", "Table19"],          # Room E
	["Table20", "Table21", "Table22", "Table23", "Table24", "Table25", "Table26", "Table27"]  # Room F
]

var long_tables := [
	"LongTable", "LongTable2", "LongTable3", "LongTable4",
	"LongTable5", "LongTable6", "LongTable7", "LongTable8",
	"LongTable9", "LongTable10", "LongTable11", "LongTable12"
]

func _ready():
	if interior_root == null:
		interior_root = get_node_or_null("map/InteriorDesign")
		if interior_root == null:
			push_error("InteriorDesign not found")
			return

	place_books_with_room_limits()
	place_one_book_on_long_table()


# ---------- Regular Tables ----------

func place_books_with_room_limits():
	var books: Array[Node3D] = []
	find_books(interior_root, books)
	books.shuffle()

	if books.size() == 0:
		print("No books found")
		return

	var room_book_count: Array[int] = []
	for i in range(rooms.size()):
		room_book_count.append(0)

	for book in books:
		var candidates: Array[Dictionary] = []
		for room_index in range(rooms.size()):
			if room_book_count[room_index] == 1 and randf() > SECOND_BOOK_PROB:
				continue
			elif room_book_count[room_index] >= MAX_BOOKS_PER_ROOM:
				continue

			for table_name in rooms[room_index]:
				var table_node = interior_root.get_node_or_null(table_name)
				if table_node:
					candidates.append({"table": table_node, "room_index": room_index})

		if candidates.size() == 0:
			print("No valid tables left for book ", book.name)
			break

		var choice: Dictionary = candidates[randi() % candidates.size()]
		var table: Node3D = choice["table"]
		var room_index: int = choice["room_index"]

		# Compute final position
		var table_pos: Vector3 = table.global_transform.origin
		var final_y: float = TABLE_TOP_Y + (BOOK_HEIGHT / 2.0)
		var final_pos: Vector3 = Vector3(
			table_pos.x + randf_range(-RANDOM_OFFSET, RANDOM_OFFSET),
			final_y,
			table_pos.z + randf_range(-RANDOM_OFFSET, RANDOM_OFFSET)
		)
		
		table.add_child(book)
		book.global_transform = Transform3D(book.global_transform.basis, final_pos)

		print("Placed ", book.name, " on ", table.name, " in room ", room_index, " at ", final_pos)

		room_book_count[room_index] += 1


# ---------- Long Tables (1 book only) ----------

func place_one_book_on_long_table():
	var books: Array[Node3D] = []
	find_books(interior_root, books)
	books.shuffle()

	if books.size() == 0:
		return

	# Pick a single book to go on a long table
	var book: Node3D = books[0]

	if long_tables.size() == 0:
		return

	# Pick a random long table
	var index: int = randi() % long_tables.size()
	var table_name: String = long_tables[index]
	var table_node: Node3D = interior_root.get_node_or_null(table_name)
	if table_node:
		var table_pos: Vector3 = table_node.global_transform.origin
		var final_pos: Vector3 = Vector3(
			table_pos.x + randf_range(-RANDOM_OFFSET, RANDOM_OFFSET),
			TABLE_TOP_Y + LONG_TABLE_BOOK_OFFSET,
			table_pos.z + randf_range(-RANDOM_OFFSET, RANDOM_OFFSET)
		)
		table_node.add_child(book)
		book.global_transform = Transform3D(book.global_transform.basis, final_pos)
		print("Placed ", book.name, " on long table ", table_name, " at ", final_pos)

	long_tables.remove_at(index)


func find_books(node: Node, out: Array[Node3D]) -> void:
	for child in node.get_children():
		if child.name.begins_with("Book_2_"):
			out.append(child)
		find_books(child, out)
