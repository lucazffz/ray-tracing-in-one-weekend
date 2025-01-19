run: clean build
	./build/ray-tracing-in-one-weekend

build:
	mkdir -p build
	touch build/output.ppm
	odin build . -out:build/ray-tracing-in-one-weekend

clean: 
	rm -rf build

view: 
	xdg-open build/output.ppm
