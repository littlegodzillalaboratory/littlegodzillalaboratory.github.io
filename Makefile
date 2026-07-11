################################################################
# PageMaker: Makefile for building ProjectSite website
# https://github.com/cliffano/pagemaker
################################################################

# PageMaker's version number
PAGEMAKER_VERSION = 1.0.0

################################################################
# User configuration variables
# https://github.com/cliffano/pagemaker#configuration
# These variables should be stored in pagemaker.yml config file,
# and they will be parsed using yq https://github.com/mikefarah/yq

# PACKAGE_NAME is the name of the node.js package
PACKAGE_NAME=$(shell yq .package_name pagemaker.yml)

# AUTHOR is the author of the node.js package
AUTHOR ?= $(shell yq .author pagemaker.yml)

$(info ################################################################)
$(info Building ProjectSite website using Makefile...)
$(info - Package name = ${PACKAGE_NAME})
$(info - Author = ${AUTHOR})

define python_venv
	. .venv/bin/activate && $(1)
endef

################################################################
# MAKE IT SO - Utility functions

define run_hook
	@if [ -f Makefile-extras ] && grep -q "^$(1):" Makefile-extras; then \
		$(MAKE) -f Makefile-extras $(1); \
	fi
endef

define deps_extra
	@if command -v apt-get > /dev/null 2>&1; then \
		if [ "$$(id -u)" = "0" ]; then \
			$(MAKE) deps-extra-apt; \
		else \
			sudo $(MAKE) deps-extra-apt; \
		fi; \
	fi
endef

define set_generator_vars
$(1): GENERATOR_COMPONENT = $$(shell yq .generator.component $(2).yml)
$(1): GENERATOR_INPUTS_PROJECT_ID = $$(shell yq .generator.inputs.project_id $(2).yml)
$(1): GENERATOR_INPUTS_PROJECT_NAME = $$(shell yq .generator.inputs.project_name $(2).yml)
$(1): GENERATOR_INPUTS_PROJECT_DESC = $$(shell yq .generator.inputs.project_desc $(2).yml)
$(1): GENERATOR_INPUTS_AUTHOR_NAME = $$(shell yq .generator.inputs.author_name $(2).yml)
$(1): GENERATOR_INPUTS_AUTHOR_EMAIL = $$(shell yq .generator.inputs.author_email $(2).yml)
$(1): GENERATOR_INPUTS_AUTHOR_URL = $$(shell yq .generator.inputs.author_url $(2).yml)
$(1): GENERATOR_INPUTS_GITHUB_ID = $$(shell yq .generator.inputs.github_id $(2).yml)
$(1): GENERATOR_INPUTS_GITHUB_REPO = $$(shell yq .generator.inputs.github_repo $(2).yml)
$(1): GENERATOR_INPUTS_GITHUB_TOKEN_PREFIX = $$(shell yq .generator.inputs.github_token_prefix $(2).yml)
endef

define update_dotfiles_from_generator
	cd stage/ && \
	  rm -rf generator-$(1)/ && \
	  git clone https://github.com/cliffano/generator-$(1) && \
	  cd generator-$(1) && \
	  make deps && \
	  node_modules/.bin/plop $(GENERATOR_COMPONENT) -- \
	    --project_id "$(GENERATOR_INPUTS_PROJECT_ID)" \
		--project_name "$(GENERATOR_INPUTS_PROJECT_NAME)" \
		--project_desc "$(GENERATOR_INPUTS_PROJECT_DESC)" \
		--author_name "$(GENERATOR_INPUTS_AUTHOR_NAME)" \
		--author_email "$(GENERATOR_INPUTS_AUTHOR_EMAIL)" \
		--author_url "$(GENERATOR_INPUTS_AUTHOR_URL)" \
		--github_id "$(GENERATOR_INPUTS_GITHUB_ID)" \
		--github_repo "$(GENERATOR_INPUTS_GITHUB_REPO)" \
		--github_token_prefix "$(GENERATOR_INPUTS_GITHUB_TOKEN_PREFIX)"
	cd stage/generator-$(1)/stage/$(GENERATOR_COMPONENT) && \
	  for dotfile in $(2); do \
		cp -R "$$dotfile" ../../../../"$$dotfile"; \
	  done
endef

define update_partials_from_generator
	cd stage/ && \
	  rm -rf generator-$(1)/ && \
	  git clone https://github.com/cliffano/generator-$(1) && \
	  cd generator-$(1) && \
	  make deps && \
	  node_modules/.bin/plop $(GENERATOR_COMPONENT)-partials -- \
	    --project_id "$(GENERATOR_INPUTS_PROJECT_ID)" \
		--project_name "$(GENERATOR_INPUTS_PROJECT_NAME)" \
		--project_desc "$(GENERATOR_INPUTS_PROJECT_DESC)" \
		--author_name "$(GENERATOR_INPUTS_AUTHOR_NAME)" \
		--author_email "$(GENERATOR_INPUTS_AUTHOR_EMAIL)" \
		--author_url "$(GENERATOR_INPUTS_AUTHOR_URL)" \
		--github_id "$(GENERATOR_INPUTS_GITHUB_ID)" \
		--github_repo "$(GENERATOR_INPUTS_GITHUB_REPO)" \
		--github_token_prefix "$(GENERATOR_INPUTS_GITHUB_TOKEN_PREFIX)"
	for block in $(2); do \
	  partial_file=$$(printf "%s" "$$block" | tr "A-Z" "a-z"); \
	  ex -s \
	    -c "/<!-- BEGIN:$$block -->/+1,/<!-- END:$$block -->/-1d" \
	    -c "/<!-- BEGIN:$$block -->/r stage/generator-$(1)/stage/$(GENERATOR_COMPONENT)-partials/$$partial_file.txt" \
	    -c 'wq' \
	    README.md; \
	done
endef

################################################################
# Base targets

# CI target to be executed by CI/CD tool
all: ci
ci: clean lint build

# Ensure stage directory exists
stage:
	mkdir -p stage

# Remove all temporary (staged, generated, cached) files
clean:
	rm -rf stage/

rmdeps:
	rm -rf node_modules/

deps:
	npm install .
	$(call deps_extra)

deps-extra-apt:
	apt-get install -y markdownlint

deps-upgrade:
	node_modules/.bin/pkjutil upgrade-dependencies
	
lint:
	node_modules/.bin/jsonlint -d data/
	node_modules/.bin/yamllint .github/workflows/*.yaml
	mdl -r ~MD002,~MD013,~MD033 $(shell find . -path ./stage -prune -o -path ./node_modules -prune -o -name "CHANGELOG.md" -prune -o -name "*.md" -print)

build:
	node_modules/.bin/jazz-cli merge data/project-info.json templates/index.md.jazz | head -c -1 > docs/index.md

test:
	node_modules/.bin/markdown-link-check docs/index.md

test-examples:
	echo "PLACEHOLDER"

# Update Makefile to the latest version tag
update-to-latest: TARGET_PAGEMAKER_VERSION = $(shell curl -s https://api.github.com/repos/cliffano/pagemaker/tags | jq -r '.[0].name')
update-to-latest: update-to-version

# Update Makefile to the main branch
update-to-main:
	curl https://raw.githubusercontent.com/cliffano/pagemaker/main/src/Makefile-pagemaker -o Makefile

# Update Makefile to the version defined in TARGET_PAGEMAKER_VERSION parameter
update-to-version:
	curl https://raw.githubusercontent.com/cliffano/pagemaker/$(TARGET_PAGEMAKER_VERSION)/src/Makefile-pagemaker -o Makefile

$(eval $(call set_generator_vars,update-dotfiles,pagemaker))
# Update dotfiles using the generator-website
update-dotfiles: stage
	$(call update_dotfiles_from_generator,website,.github/. .gitignore .yamllint)

# Update partial snippets using the generator-website
$(eval $(call set_generator_vars,update-partials,pagemaker))
update-partials: stage
	$(call update_partials_from_generator,website,AVATAR BADGES DEVELOPERS_GUIDE)

.PHONY: $(1) all ci clean deps deps-extra-apt deps-upgrade rmdeps lint build test update-to-latest update-to-main update-to-version update-dotfiles update-partials
