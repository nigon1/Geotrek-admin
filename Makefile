SHELL = /bin/bash

listen=localhost:8000
baseurl=http://$(listen)
root=$(shell pwd)
version=$(shell git describe --tags --abbrev=0)

bin/buildout:
	virtualenv .
	mkdir -p lib/eggs
	wget http://python-distribute.org/bootstrap.py
	bin/python bootstrap.py
	rm bootstrap.py

install: bin/buildout

clean_harmless:
	find caminae/ -name "*.pyc" -exec rm {} \;

clean: clean_harmless
	rm -rf bin/ lib/ local/ include/ *.egg-info/
	rm -rf var/
	rm -rf etc/init/
	rm -f .installed.cfg
	rm -f install.log

.PHONY: all_makemessages all_compilemessages

all_makemessages: bin/
	for dir in `find caminae/ -type d -name locale`; do pushd `dirname $$dir` > /dev/null; $(root)/bin/django-admin makemessages -a; popd > /dev/null; done

all_compilemessages: bin/
	for dir in `find caminae/ -type d -name locale`; do pushd `dirname $$dir` > /dev/null; $(root)/bin/django-admin compilemessages; popd > /dev/null; done

release:
	git archive --format=zip --prefix="caminae-$(version)/" $(version) > ../caminae-src-$(version).zip

unit_tests: bin/buildout clean_harmless
	bin/buildout -Nvc buildout-tests.cfg
	bin/develop update -f
	bin/django jenkins --coverage-rcfile=.coveragerc --output-dir=var/reports/ authent core land maintenance trekking common infrastructure mapentity

unit_tests_js:
	casperjs --baseurl=$(baseurl) --reportdir=var/reports caminae/tests/test_qunit.js

functional_tests:
	casperjs --baseurl=$(baseurl) --save=var/reports/FUNC-auth.xml caminae/tests/auth.js
	casperjs --baseurl=$(baseurl) --save=var/reports/FUNC-88.xml caminae/tests/story_88_user_creation.js
	casperjs --baseurl=$(baseurl) --save=var/reports/FUNC-test_utils.xml caminae/tests/test_utils.js

tests: unit_tests functional_tests

serve: bin/buildout clean_harmless all_compilemessages
	bin/buildout -Nvc buildout-dev.cfg
	bin/django syncdb --noinput --migrate
	bin/django runcserver $(listen)

load_data:
	# /!\ will delete existing data
	bin/django loaddata development-pne
	for dir in `find caminae/ -type d -name upload`; do pushd `dirname $$dir` > /dev/null; cp -R upload/* $(root)/var/media/upload/ ; popd > /dev/null; done

deploy: bin/buildout clean_harmless all_compilemessages
	bin/buildout -Nvc buildout-prod.cfg
	touch lib/parts/django/django_extrasettings/settings_production.py
	bin/develop update -f
	bin/django syncdb --noinput --migrate
	bin/django collectstatic --noinput
	bin/django update_translation_fields
	bin/supervisorctl restart all

deploy_demo: deploy load_data