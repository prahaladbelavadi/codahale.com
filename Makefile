build: clean
	bundle exec jekyll build

clean:
	rm -rf _site .sass-cache

server: clean
	bundle exec jekyll server --watch

install:
	bundle install --path vendor/bundle

publish: build
	aws s3 sync _site s3://codahale.com --acl public-read --cache-control max-age=300
