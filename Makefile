build: clean
	@jekyll

clean:
	rm -rf _site

server: clean
	jekyll

publish: build
	@rsync -avz _site/ codahale@codahale.com:~/codahale.com