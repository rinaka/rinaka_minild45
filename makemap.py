# This python script reads a 28x22 PNG image representing a game level
# and outputs a sequence of data that represents the game map
# NOTE: white = background, black = wall
# other colors are ignored (might be used to mark objects)

from PIL import Image

img = Image.open("map.png")

level_map = [[0x80 for i in range(22)] for j in range(32)]

pixels = img.load()

black = (0, 0, 0)

# first we process the map
for j in range(22):
	for i in range(28):
		c = pixels[i, j]
		if c == black:
			level_map[i+2][j] = 0x85

# then we adjust the tiles
for j in range(22):
	for i in range(2, 30):
		if level_map[i][j] != 0x80:
			c = 0
			if (j > 0) and (level_map[i][j-1] != 0x80):
				c = c + 1
			if (i < 28) and (level_map[i+1][j] != 0x80):
				c = c + 2
			if (j < 21) and (level_map[i][j+1] != 0x80):
				c = c + 4
			if (i > 0) and (level_map[i-1][j] != 0x80):
				c = c + 8
			if (c == 2) or (c == 8) or (c == 10):
				level_map[i][j] = 0x82 - i%2
			elif (c == 1) or (c == 4) or (c == 5):
				level_map[i][j] = 0x84 - j%2
			
# finally, print the layout
for j in range(22):
	print "dm ",
	for i in range(32):
		print hex(level_map[i][j]),
		if i < 31:
			print ",",
		else:
			print
