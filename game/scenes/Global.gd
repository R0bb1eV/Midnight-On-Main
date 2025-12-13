extends Node 

var books_collected := 0 
var total_books := 5

# Critical: keep a persistent list of collected book IDs
var collected_book_ids: Array = []
