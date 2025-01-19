run: build
	./build/ray-tracing-in-one-weekend

build:
	mkdir -p build
	odin build . -out:build/ray-tracing-in-one-weekend

clean: 
	rm -rf build
