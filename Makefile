build: clean
	@jekyll

clean:
	rm -rf _site

server: clean
	jekyll --server --auto

publish: build
	@rsync -avz --exclude Makefile --exclude README.md _site/ codahale@codahale.com:~/codahale.com