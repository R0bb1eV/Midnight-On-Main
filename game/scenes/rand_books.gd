extends Node3D

@export var interior_root: Node3D = null

var TABLE_TOP_Y := -0.74636995792389
var BOOK_HEIGHT := 3.8
var RANDOM_OFFSET := 0.15

func _ready():
	if interior_root == null:
		interior_root = get_node_or_null("map/InteriorDesign")
		if interior_root == null:
			push_error("InteriorDesign not found")
			return

	place_books_on_first_five_tables()


func place_books_on_first_five_tables():
	var tables: Array = []
	get_specific_tables(interior_root, tables)
	tables.shuffle()

	print("Tables found: ", tables)

	var books: Array = []
	find_books(interior_root, books)
	books.shuffle()

	if books.size() == 0:
		print("No books found")
		return

	var count = min(books.size(), tables.size())

	for i in range(count):
		var table: Node3D = tables[i]
		var book: Node3D = books[i]

		var table_pos = table.global_transform.origin

		var final_y = TABLE_TOP_Y + (BOOK_HEIGHT / 2.0)

		var final_pos = Vector3(
			table_pos.x + randf_range(-RANDOM_OFFSET, RANDOM_OFFSET),
			final_y,
			table_pos.z + randf_range(-RANDOM_OFFSET, RANDOM_OFFSET)
		)

		table.add_child(book)
		book.global_transform = Transform3D(book.global_transform.basis, final_pos)

		print("Placed ", book.name, " on ", table.name, " at ", final_pos)


func get_specific_tables(node: Node, out: Array):
	for child in node.get_children():
		if child.name.begins_with("Table"):
			var num_str := child.name.substr(5)
			if num_str.is_valid_int():
				var num := int(num_str)
				if num >= 1 and num <= 31:
					out.append(child)
		get_specific_tables(child, out)


func find_books(node: Node, out: Array):
	for child in node.get_children():
		if child.name.begins_with("Book_2_"):
			out.append(child)
		find_books(child, out)
