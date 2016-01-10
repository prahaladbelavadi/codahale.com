build: clean
	jekyll build

clean:
	rm -rf _site

server: clean
	jekyll server --watch

install:
	gem install jekyll jekyll-assets sass rouge

publish: build
	@rsync -avz --exclude Makefile --exclude README.md _site/ codahale@ssh.codahale.com:~/codahale.com
