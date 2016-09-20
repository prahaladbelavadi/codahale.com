build: clean
	jekyll build

clean:
	rm -rf _site

server: clean
	jekyll server --watch

install:
	gem install jekyll jekyll-assets sass rouge

publish: build
	aws s3 sync _site s3://codahale.com --acl public-read 
