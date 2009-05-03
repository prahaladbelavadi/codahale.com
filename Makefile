build: clean
	@jekyll

clean:
	rm -rf _site

server: clean
	jekyll --server --auto

publish: build
	@rsync -avz _site/ codahale@codahale.com:~/codahale.com