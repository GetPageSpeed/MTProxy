OBJ	=	objs
DEP	=	dep
EXE = ${OBJ}/bin

COMMIT := $(shell git log -1 --pretty=format:"%H")
VERSION := $(shell git describe --tags --match 'v*' --abbrev=0 2>/dev/null | sed 's/^v//' || echo "unknown")
ifneq ($(EXTRA_VERSION),)
VERSION := $(EXTRA_VERSION)
endif

BITNESS_FLAGS =
ifeq ($(m), 32)
BITNESS_FLAGS = -m32
endif
ifeq ($(m), 64)
BITNESS_FLAGS = -m64
endif

# Determine the host architecture using arch
HOST_ARCH := $(shell arch)

# Default CFLAGS and LDFLAGS
COMMON_CFLAGS := -O3 -std=gnu11 -Wall -fno-strict-aliasing -fno-strict-overflow -fwrapv -DAES=1 -DCOMMIT=\"${COMMIT}\" -DVERSION=\"${VERSION}\" -D_GNU_SOURCE=1 -D_FILE_OFFSET_BITS=64 -Wno-array-bounds -Wno-implicit-function-declaration
COMMON_LDFLAGS := -ggdb -rdynamic -lm -lrt -lcrypto -lz -lpthread

# Auto-detect libunwind for stack traces on musl/Alpine (test/CI builds)
LIBUNWIND_CFLAGS := $(shell pkg-config --cflags libunwind 2>/dev/null)
LIBUNWIND_LDFLAGS := $(shell pkg-config --libs libunwind 2>/dev/null)
ifneq ($(LIBUNWIND_LDFLAGS),)
COMMON_CFLAGS += -DHAVE_LIBUNWIND $(LIBUNWIND_CFLAGS)
COMMON_LDFLAGS += $(LIBUNWIND_LDFLAGS)
endif

# Support additional flags (e.g. sanitizers): make EXTRA_CFLAGS="-fsanitize=address"
COMMON_CFLAGS += $(EXTRA_CFLAGS)
COMMON_LDFLAGS += $(EXTRA_LDFLAGS)

# Architecture-specific CFLAGS
ifeq ($(HOST_ARCH), x86_64)
CFLAGS := $(COMMON_CFLAGS) -mpclmul -march=core2 -mfpmath=sse -mssse3 $(BITNESS_FLAGS)
else ifeq ($(HOST_ARCH), aarch64)
CFLAGS := $(COMMON_CFLAGS) $(BITNESS_FLAGS)
else ifeq ($(HOST_ARCH), arm64)
CFLAGS := $(COMMON_CFLAGS) $(BITNESS_FLAGS)
endif

# Architecture-specific LDFLAGS (if needed, here kept same for simplicity)
LDFLAGS := $(COMMON_LDFLAGS)

LIB = ${OBJ}/lib
CINCLUDE = -iquote common -iquote .

LIBLIST = ${LIB}/libkdb.a

PROJECTS = common jobs mtproto net crypto engine

OBJDIRS := ${OBJ} $(addprefix ${OBJ}/,${PROJECTS}) ${EXE} ${LIB}
DEPDIRS := ${DEP} $(addprefix ${DEP}/,${PROJECTS})
ALLDIRS := ${DEPDIRS} ${OBJDIRS}


.PHONY:	all clean lint tests test test-tls test-multi-secret test-secret-limit test-ip-acl test-drs-delays docker-image-amd64 docker-run-help-amd64 docker-image-arm64 docker-run-help-arm64 fuzz fuzz-run

EXELIST	:= ${EXE}/mtproto-proxy


OBJECTS	=	\
  ${OBJ}/mtproto/mtproto-proxy.o ${OBJ}/mtproto/mtproto-config.o ${OBJ}/mtproto/mtproto-dc-table.o ${OBJ}/net/net-tcp-rpc-ext-server.o

DEPENDENCE_CXX		:=	$(subst ${OBJ}/,${DEP}/,$(patsubst %.o,%.d,${OBJECTS_CXX}))
DEPENDENCE_STRANGE	:=	$(subst ${OBJ}/,${DEP}/,$(patsubst %.o,%.d,${OBJECTS_STRANGE}))
DEPENDENCE_NORM	:=	$(subst ${OBJ}/,${DEP}/,$(patsubst %.o,%.d,${OBJECTS}))

LIB_OBJS_NORMAL := \
	${OBJ}/common/crc32c.o \
	${OBJ}/common/pid.o \
	${OBJ}/common/sha1.o \
	${OBJ}/common/sha256.o \
	${OBJ}/common/md5.o \
	${OBJ}/common/resolver.o \
	${OBJ}/common/parse-config.o \
	${OBJ}/crypto/aesni256.o \
	${OBJ}/jobs/jobs.o ${OBJ}/common/mp-queue.o \
	${OBJ}/net/net-events.o ${OBJ}/net/net-msg.o ${OBJ}/net/net-msg-buffers.o \
	${OBJ}/net/net-config.o ${OBJ}/net/net-crypto-aes.o ${OBJ}/net/net-crypto-dh.o ${OBJ}/net/net-timers.o \
	${OBJ}/net/net-connections.o \
	${OBJ}/net/net-rpc-targets.o \
	${OBJ}/net/net-tcp-connections.o ${OBJ}/net/net-tcp-drs.o ${OBJ}/net/net-tcp-rpc-common.o ${OBJ}/net/net-tcp-rpc-client.o ${OBJ}/net/net-tcp-rpc-server.o \
	${OBJ}/net/net-http-server.o ${OBJ}/net/net-http-parse.o ${OBJ}/net/net-tls-parse.o ${OBJ}/net/net-ip-acl.o \
	${OBJ}/common/tl-parse.o ${OBJ}/common/common-stats.o \
	${OBJ}/engine/engine.o ${OBJ}/engine/engine-signals.o \
	${OBJ}/engine/engine-net.o \
	${OBJ}/engine/engine-rpc.o \
	${OBJ}/engine/engine-rpc-common.o \
	${OBJ}/net/net-thread.o ${OBJ}/net/net-stats.o ${OBJ}/common/proc-stat.o \
	${OBJ}/common/kprintf.o \
	${OBJ}/common/precise-time.o ${OBJ}/common/cpuid.o \
	${OBJ}/common/server-functions.o ${OBJ}/common/crc32.o \

LIB_OBJS := ${LIB_OBJS_NORMAL}

DEPENDENCE_LIB	:=	$(subst ${OBJ}/,${DEP}/,$(patsubst %.o,%.d,${LIB_OBJS}))

DEPENDENCE_ALL		:=	${DEPENDENCE_NORM} ${DEPENDENCE_STRANGE} ${DEPENDENCE_LIB}

OBJECTS_ALL		:=	${OBJECTS} ${LIB_OBJS}

all:	${ALLDIRS} ${EXELIST} 
dirs: ${ALLDIRS}
create_dirs_and_headers: ${ALLDIRS} 

${ALLDIRS}:	
	@test -d $@ || mkdir -p $@

-include ${DEPENDENCE_ALL}

${OBJECTS}: ${OBJ}/%.o: %.c | create_dirs_and_headers
	${CC} ${CFLAGS} ${CINCLUDE} -c -MP -MD -MF ${DEP}/$*.d -MQ ${OBJ}/$*.o -o $@ $<

${LIB_OBJS_NORMAL}: ${OBJ}/%.o: %.c | create_dirs_and_headers
	${CC} ${CFLAGS} -fpic ${CINCLUDE} -c -MP -MD -MF ${DEP}/$*.d -MQ ${OBJ}/$*.o -o $@ $<

${EXELIST}: ${LIBLIST}

${EXE}/mtproto-proxy:	${OBJ}/mtproto/mtproto-proxy.o ${OBJ}/mtproto/mtproto-config.o ${OBJ}/mtproto/mtproto-dc-table.o ${OBJ}/net/net-tcp-rpc-ext-server.o
	${CC} -o $@ $^ ${LIB}/libkdb.a ${LDFLAGS}

${LIB}/libkdb.a: ${LIB_OBJS}
	rm -f $@ && ar rcs $@ $^

clean:
	rm -rf ${OBJ} ${DEP} ${EXE} || true

lint:
	cppcheck --enable=warning,portability,performance \
	  --error-exitcode=1 \
	  --suppressions-list=.cppcheck-suppressions \
	  --suppress=missingIncludeSystem \
	  --std=c11 -I common -I . \
	  common/ jobs/ mtproto/ net/ crypto/ engine/

force-clean: clean

# Docker-based amd64 build and smoke test
DOCKER ?= docker
DOCKER_PLATFORM ?= linux/amd64
DOCKER_TEST_IMAGE ?= mtproxy:test-amd64

docker-image-amd64:
	${DOCKER} buildx build --platform ${DOCKER_PLATFORM} --load -t ${DOCKER_TEST_IMAGE} .

docker-run-help-amd64: docker-image-amd64
	${DOCKER} run --rm --platform ${DOCKER_PLATFORM} --entrypoint /opt/mtproxy/mtproto-proxy ${DOCKER_TEST_IMAGE} 2>&1 | grep -q "Invoking engine"

docker-image-arm64:
	${DOCKER} buildx build --platform linux/arm64 --load -t mtproxy:test-arm64 .

docker-run-help-arm64: docker-image-arm64
	${DOCKER} run --rm --platform linux/arm64 --entrypoint /opt/mtproxy/mtproto-proxy mtproxy:test-arm64 2>&1 | grep -q "Invoking engine"

tests: docker-run-help-amd64
	@echo "Smoke test passed: amd64 image builds and binary starts (--help)."

test:
	@# Generate secret if not provided
	@if [ -z "$$MTPROXY_SECRET" ]; then \
		export MTPROXY_SECRET=$$(head -c 16 /dev/urandom | xxd -ps); \
		echo "Generated MTPROXY_SECRET: $$MTPROXY_SECRET"; \
	fi && \
	export MTPROXY_SECRET=$${MTPROXY_SECRET:-$$(head -c 16 /dev/urandom | xxd -ps)} && \
	echo "Using secret: $$MTPROXY_SECRET" && \
	timeout 1200s docker compose -f tests/docker-compose.test.yml up --build --exit-code-from tester || \
		(echo "Test timed out or failed"; docker compose -f tests/docker-compose.test.yml down; exit 1)

test-tls:
	@if [ -z "$$MTPROXY_SECRET" ]; then \
		export MTPROXY_SECRET=$$(head -c 16 /dev/urandom | xxd -ps); \
		echo "Generated MTPROXY_SECRET: $$MTPROXY_SECRET"; \
	fi && \
	export MTPROXY_SECRET=$${MTPROXY_SECRET:-$$(head -c 16 /dev/urandom | xxd -ps)} && \
	echo "Using secret: $$MTPROXY_SECRET" && \
	timeout 300s docker compose -f tests/docker-compose.tls-test.yml up --build --exit-code-from tester || \
		(echo "TLS test timed out or failed"; \
		docker compose -f tests/docker-compose.tls-test.yml logs mtproxy; \
		docker compose -f tests/docker-compose.tls-test.yml down; exit 1)
	docker compose -f tests/docker-compose.tls-test.yml down

test-multi-secret:
	@export MTPROXY_SECRET_1=$$(head -c 16 /dev/urandom | xxd -ps) && \
	export MTPROXY_SECRET_2=$$(head -c 16 /dev/urandom | xxd -ps) && \
	echo "Using secrets: $$MTPROXY_SECRET_1, $$MTPROXY_SECRET_2" && \
	timeout 300s docker compose -f tests/docker-compose.multi-secret-test.yml up --build --exit-code-from tester || \
		(echo "Multi-secret test timed out or failed"; \
		docker compose -f tests/docker-compose.multi-secret-test.yml logs mtproxy; \
		docker compose -f tests/docker-compose.multi-secret-test.yml down; exit 1)
	@echo "Checking connection link output in proxy logs..."
	@docker compose -f tests/docker-compose.multi-secret-test.yml logs mtproxy 2>&1 | grep -q "t.me/proxy" || \
		(echo "FAIL: No connection links found in proxy logs"; exit 1)
	docker compose -f tests/docker-compose.multi-secret-test.yml down

test-secret-limit:
	@export MTPROXY_SECRET_1=$$(head -c 16 /dev/urandom | xxd -ps) && \
	export MTPROXY_SECRET_2=$$(head -c 16 /dev/urandom | xxd -ps) && \
	echo "Using secrets: $$MTPROXY_SECRET_1 (unlimited), $$MTPROXY_SECRET_2 (limit=5)" && \
	timeout 300s docker compose -f tests/docker-compose.secret-limit-test.yml up --build --exit-code-from tester || \
		(echo "Secret limit test timed out or failed"; \
		docker compose -f tests/docker-compose.secret-limit-test.yml logs mtproxy; \
		docker compose -f tests/docker-compose.secret-limit-test.yml down; exit 1)
	docker compose -f tests/docker-compose.secret-limit-test.yml down

test-ip-acl:
	@if [ -z "$$MTPROXY_SECRET" ]; then \
		export MTPROXY_SECRET=$$(head -c 16 /dev/urandom | xxd -ps); \
		echo "Generated MTPROXY_SECRET: $$MTPROXY_SECRET"; \
	fi && \
	export MTPROXY_SECRET=$${MTPROXY_SECRET:-$$(head -c 16 /dev/urandom | xxd -ps)} && \
	echo "Using secret: $$MTPROXY_SECRET" && \
	docker compose -f tests/docker-compose.ip-acl-test.yml build && \
	docker compose -f tests/docker-compose.ip-acl-test.yml up -d --wait mtproxy && \
	echo "Phase 1: testing blocked connections..." && \
	docker compose -f tests/docker-compose.ip-acl-test.yml run --rm blocked-tester && \
	echo "Phase 2: testing allowed connections..." && \
	docker compose -f tests/docker-compose.ip-acl-test.yml run --rm tester || \
		(echo "IP ACL test failed"; \
		docker compose -f tests/docker-compose.ip-acl-test.yml logs mtproxy; \
		docker compose -f tests/docker-compose.ip-acl-test.yml down -v; exit 1)
	docker compose -f tests/docker-compose.ip-acl-test.yml down -v

test-drs-delays:
	@if [ -z "$$MTPROXY_SECRET" ]; then \
		export MTPROXY_SECRET=$$(head -c 16 /dev/urandom | xxd -ps); \
		echo "Generated MTPROXY_SECRET: $$MTPROXY_SECRET"; \
	fi && \
	export MTPROXY_SECRET=$${MTPROXY_SECRET:-$$(head -c 16 /dev/urandom | xxd -ps)} && \
	echo "Using secret: $$MTPROXY_SECRET" && \
	timeout 300s docker compose -f tests/docker-compose.drs-delays-test.yml up --build --exit-code-from tester || \
		(echo "DRS delays test timed out or failed"; \
		docker compose -f tests/docker-compose.drs-delays-test.yml logs mtproxy; \
		docker compose -f tests/docker-compose.drs-delays-test.yml down; exit 1)
	docker compose -f tests/docker-compose.drs-delays-test.yml down

FUZZ_DURATION ?= 60

fuzz:
	$(MAKE) -C fuzz

fuzz-run:
	$(MAKE) -C fuzz run FUZZ_DURATION=$(FUZZ_DURATION)
