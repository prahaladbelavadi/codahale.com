build: clean
	jekyll build

clean:
	rm -rf _site

server: clean
	jekyll server --watch

publish: build
	@rsync -avz --exclude Makefile --exclude README.md _site/ codahale@codahale.com:~/codahale.com