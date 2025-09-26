all:
	zig build
clean:
	rm -r zig-out
	rm -r .zig-cache
