# Release tasks. pesde and wally come from rokit; run from this folder.
#
# wally clones its index through libgit2, which can't use a git rewrite of https://github.com/ to SSH.
# If `github-https` is on PATH it runs wally with that rewrite turned off; otherwise wally runs as is.
GITHUB_HTTPS := $(shell command -v github-https 2> /dev/null)

.PHONY: wally wally-login wally-publish pesde-publish publish

# Builds the Wally package, lists its files and test-installs its dependencies.
wally:
	@$(GITHUB_HTTPS) scripts/wally.sh

# Once per machine, before the first wally-publish. Opens a GitHub device login.
wally-login:
	@$(GITHUB_HTTPS) scripts/wally.sh login

wally-publish:
	@$(GITHUB_HTTPS) scripts/wally.sh publish

pesde-publish:
	@pesde publish -y

# Both registries, after bumping pesde.toml and tagging the release.
publish: pesde-publish wally-publish
