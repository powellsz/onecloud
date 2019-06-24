#####################################################

REPO_PREFIX := yunion.io/x/onecloud
VENDOR_PATH := $(REPO_PREFIX)/vendor
VERSION_PKG := $(VENDOR_PATH)/yunion.io/x/pkg/util/version
ROOT_DIR := $(CURDIR)
BUILD_DIR := $(ROOT_DIR)/_output
BIN_DIR := $(BUILD_DIR)/bin
BUILD_SCRIPT := $(ROOT_DIR)/build/build.sh

GIT_COMMIT := $(shell git rev-parse --short HEAD)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
GIT_VERSION := $(shell git describe --tags --abbrev=14 $(GIT_COMMIT)^{commit})
GIT_TREE_STATE := $(shell s=`git status --porcelain 2>/dev/null`; if [ -z "$$s" ]; then echo "clean"; else echo "dirty"; fi)
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

LDFLAGS := "-w \
	-X $(VERSION_PKG).gitVersion=$(GIT_VERSION) \
	-X $(VERSION_PKG).gitCommit=$(GIT_COMMIT) \
	-X $(VERSION_PKG).gitBranch=$(GIT_BRANCH) \
	-X $(VERSION_PKG).buildDate=$(BUILD_DATE) \
	-X $(VERSION_PKG).gitTreeState=$(GIT_TREE_STATE) \
	-X $(VERSION_PKG).gitMajor=0 \
	-X $(VERSION_PKG).gitMinor=0"


#####################################################

GO_BUILD := go build -mod vendor -ldflags $(LDFLAGS)
GO_INSTALL := go install -ldflags $(LDFLAGS)
GO_TEST := go test

PKGS := go list ./...

CGO_CFLAGS_ENV = $(shell go env CGO_CFLAGS)
CGO_LDFLAGS_ENV = $(shell go env CGO_LDFLAGS)

ifdef LIBQEMUIO_PATH
    X_CGO_CFLAGS := ${CGO_CFLAGS_ENV} -I${LIBQEMUIO_PATH}/src -I${LIBQEMUIO_PATH}/src/include
    X_CGO_LDFLAGS := ${CGO_LDFLAGS_ENV} -laio -lqemuio -lpthread  -L ${LIBQEMUIO_PATH}/src
endif

export GO111MODULE:=on
export CGO_CFLAGS = ${X_CGO_CFLAGS}
export CGO_LDFLAGS = ${X_CGO_LDFLAGS}

all: build


install: prepare_dir
	@for PKG in $$( $(PKGS) | grep -w "$(filter-out $@,$(MAKECMDGOALS))" ); do \
		echo $$PKG; \
		$(GO_INSTALL) $$PKG; \
	done


build: gendoc
	$(MAKE) $(filter-out cmd/host-image, $(wildcard cmd/*))

gendoc:
	@sh build/gendoc.sh

gencopyright:
	@sh scripts/gencopyright.sh pkg cmd

test:
	@go test $(shell go list ./... | egrep -v 'host-image|hostimage')

vet:
	go vet ./...

cmd/%: prepare_dir fmt
	$(GO_BUILD) -o $(BIN_DIR)/$(shell basename $@) $(REPO_PREFIX)/$@


pkg/%: prepare_dir fmt
	$(GO_INSTALL) $(REPO_PREFIX)/$@


# a hack
rpm:
	$(MAKE) $(patsubst %,cmd/%,$(filter-out $@,$(MAKECMDGOALS)))
	$(foreach cmd,$(filter-out $@,$(MAKECMDGOALS)),$(BUILD_SCRIPT) $(cmd);)

rpmclean:
	rm -fr $(BUILD_DIR)/rpms

prepare_dir: bin_dir


bin_dir: output_dir
	@mkdir -p $(BUILD_DIR)/bin


output_dir:
	@mkdir -p $(BUILD_DIR)


.PHONY: all build prepare_dir clean fmt rpm


clean:
	@rm -fr $(BUILD_DIR)


fmt:
	@find . -type f -name "*.go" -not -path "./_output/*" \
		-not -path "./vendor/*" | xargs gofmt -s -w

define depDeprecated
OneCloud now requires using go-mod for dependency management.  dep target,
vendor files will be removed in future versions

Follow the following link to find out more about go-mod

 - https://blog.golang.org/using-go-modules
 - https://github.com/golang/go/wiki/Modules

Switching to "make mod"...

endef

dep: export depDeprecated:=$(depDeprecated)
dep:
	@echo "$$depDeprecated"
	@$(MAKE) mod

mod:
	go get $(patsubst %,%@master,$(shell go mod edit -print  | sed -n -r -e 's|.*(yunion.io/x/[a-z]+) v.*|\1|p'))
	go mod tidy
	go mod vendor -v

%:
	@:

# Use docker build binaries
# Args:
#   WHAT: Directory names to build
#
#
# Example:
# make docker_build
# make docker_build WHAT='cmd/climc cmd/region'
docker_build:
	$(ROOT_DIR)/build/docker_build.sh $(WHAT)
