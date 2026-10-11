GITHUB_HTTPS := $(shell command -v github-https 2> /dev/null)

.PHONY: wally wally-login wally-publish pesde-publish publish

wally:
	@$(GITHUB_HTTPS) scripts/wally.sh

wally-login:
	@$(GITHUB_HTTPS) scripts/wally.sh login

wally-publish:
	@$(GITHUB_HTTPS) scripts/wally.sh publish

pesde-publish:
	@pesde publish -y

publish: pesde-publish wally-publish
