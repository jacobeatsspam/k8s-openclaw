CHART_FILE := helm/Chart.yaml
OPENCLAW_VERSION := $(shell sed -n 's/^appVersion:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}[[:space:]]*$$/\1/p' $(CHART_FILE))
OPENCLAW_REF ?= $(if $(filter v%,$(OPENCLAW_VERSION)),$(OPENCLAW_VERSION),v$(OPENCLAW_VERSION))
IMAGE ?= k8s-openclaw:$(OPENCLAW_REF)

.PHONY: help docker-build docker-bake-print

help:
	@printf 'Targets:\n'
	@printf '  docker-build       Build and load the Docker image locally\n'
	@printf '  docker-bake-print  Print the resolved Docker Bake configuration\n'
	@printf '\nVariables:\n'
	@printf '  OPENCLAW_REF=%s\n' '$(OPENCLAW_REF)'
	@printf '  IMAGE=%s\n' '$(IMAGE)'

docker-build:
	OPENCLAW_REF='$(OPENCLAW_REF)' docker buildx bake \
		--file docker/docker-bake.hcl \
		--set docker-openclaw.tags='$(IMAGE)' \
		--load \
		docker-openclaw

docker-bake-print:
	OPENCLAW_REF='$(OPENCLAW_REF)' docker buildx bake \
		--file docker/docker-bake.hcl \
		--set docker-openclaw.tags='$(IMAGE)' \
		--print \
		docker-openclaw
