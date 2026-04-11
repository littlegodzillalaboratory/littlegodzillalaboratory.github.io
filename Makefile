################################################################
# PageMaker: Makefile for building ProjectSite website
# https://github.com/cliffano/pagemaker
################################################################

# PageMaker's version number
PAGEMAKER_VERSION = 0.10.0

$(info ################################################################)
$(info Building ProjectSite website using Makefile:)

define python_venv
	. .venv/bin/activate && $(1)
endef

################################################################
# Base targets

# CI target to be executed by CI/CD tool
all: ci
ci: clean deps lint build

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

deps-extra-apt:
	apt-get install -y markdownlint

lint:
	node_modules/.bin/jsonlint -d data/
	node_modules/.bin/yamllint .github/workflows/*.yaml
	mdl -r ~MD002,~MD013 docs/
	mdl -r ~MD002,~MD013,~MD033 *.md

build:
	node_modules/.bin/jazz-cli merge data/project-info.json templates/index.md.jazz | head -c -1 > docs/index.md

test:
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

# Update dotfiles using the generator-python
update-dotfiles: GENERATOR_COMPONENT = $(shell yq .generator.component pagemaker.yml)
update-dotfiles: GENERATOR_INPUTS_PROJECT_ID = $(shell yq .generator.inputs.project_id pagemaker.yml)
update-dotfiles: GENERATOR_INPUTS_PROJECT_NAME = $(shell yq .generator.inputs.project_name pagemaker.yml)
update-dotfiles: GENERATOR_INPUTS_PROJECT_DESC = $(shell yq .generator.inputs.project_desc pagemaker.yml)
update-dotfiles: GENERATOR_INPUTS_AUTHOR_NAME = $(shell yq .generator.inputs.author_name pagemaker.yml)
update-dotfiles: GENERATOR_INPUTS_AUTHOR_EMAIL = $(shell yq .generator.inputs.author_email pagemaker.yml)
update-dotfiles: GENERATOR_INPUTS_GITHUB_ID = $(shell yq .generator.inputs.github_id pagemaker.yml)
update-dotfiles: GENERATOR_INPUTS_GITHUB_REPO = $(shell yq .generator.inputs.github_repo pagemaker.yml)
update-dotfiles: stage
	cd stage/ && \
	  rm -rf generator-website/ && \
	  git clone https://github.com/cliffano/generator-website && \
	  cd generator-website && \
	  make deps && \
	  node_modules/.bin/plop $(GENERATOR_COMPONENT) -- \
	    --project_id "$(GENERATOR_INPUTS_PROJECT_ID)" \
		  --project_name "$(GENERATOR_INPUTS_PROJECT_NAME)" \
		  --project_desc "$(GENERATOR_INPUTS_PROJECT_DESC)" \
		  --author_name "$(GENERATOR_INPUTS_AUTHOR_NAME)" \
		  --author_email "$(GENERATOR_INPUTS_AUTHOR_EMAIL)" \
		  --github_id "$(GENERATOR_INPUTS_GITHUB_ID)" \
		  --github_repo "$(GENERATOR_INPUTS_GITHUB_REPO)"
	cd stage/generator-website/stage/$(GENERATOR_COMPONENT) && \
	  cp -R .github/* ../../../../.github/ && \
	  cp .gitignore ../../../../.gitignore && \
	  cp .yamllint ../../../../.yamllint

.PHONY: all ci clean deps deps-extra-apt lint build test update-to-latest update-to-main update-to-version update-dotfiles