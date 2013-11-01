# This python script will convert an image to MSX screen 2 format
# TODO: use PIL instead of raw bitmap manipulation.

with open("image.bin", "wb") as o:
	with open("title.bmp", "rb") as f:
		b = f.read(2)
		if b != "BM":
			print "Invalid header"
			exit()
		#skip eight bytes of the header
		f.read(8)
		#read offset
		b = f.read(4)
		ofs = 0
		p = 1
		for k in b:
			ofs = ofs + ord(k)*p
			p = 256*p
		f.seek(ofs)
		ct = 0
		b = f.read(2048)
		while ct < 8:
			col = 0
			while col < 256:
				r = 0
				while r < 8:
					ofs = r*256+col
					ob = 0
					w = 0
					z = 128
					while w < 8:
						if ord(b[ofs+w]) != 0:
							ob = ob | z
						w = w + 1
						z = z / 2
					o.write(chr(ob))
					r = r + 1
				col = col + 8
			b = f.read(2048)
			ct = ct + 1
		f.close()
	o.close()
print "Finished!"
