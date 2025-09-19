OBJ	=	objs
DEP	=	dep
EXE = ${OBJ}/bin

COMMIT := $(shell git log -1 --pretty=format:"%H")

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
COMMON_CFLAGS := -O3 -std=gnu11 -Wall -fno-strict-aliasing -fno-strict-overflow -fwrapv -DAES=1 -DCOMMIT=\"${COMMIT}\" -D_GNU_SOURCE=1 -D_FILE_OFFSET_BITS=64
COMMON_LDFLAGS := -ggdb -rdynamic -lm -lrt -lcrypto -lz -lpthread

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


.PHONY:	all clean tests docker-image-amd64 docker-run-help-amd64

EXELIST	:= ${EXE}/mtproto-proxy


OBJECTS	=	\
  ${OBJ}/mtproto/mtproto-proxy.o ${OBJ}/mtproto/mtproto-config.o ${OBJ}/net/net-tcp-rpc-ext-server.o

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
	${OBJ}/net/net-tcp-connections.o ${OBJ}/net/net-tcp-rpc-common.o ${OBJ}/net/net-tcp-rpc-client.o ${OBJ}/net/net-tcp-rpc-server.o \
	${OBJ}/net/net-http-server.o \
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

${EXE}/mtproto-proxy:	${OBJ}/mtproto/mtproto-proxy.o ${OBJ}/mtproto/mtproto-config.o ${OBJ}/net/net-tcp-rpc-ext-server.o
	${CC} -o $@ $^ ${LIB}/libkdb.a ${LDFLAGS}

${LIB}/libkdb.a: ${LIB_OBJS}
	rm -f $@ && ar rcs $@ $^

clean:
	rm -rf ${OBJ} ${DEP} ${EXE} || true

force-clean: clean

# Docker-based amd64 build and smoke test
DOCKER ?= docker
DOCKER_PLATFORM ?= linux/amd64
DOCKER_TEST_IMAGE ?= mtproxy:test-amd64

docker-image-amd64:
	${DOCKER} buildx build --platform ${DOCKER_PLATFORM} --load -t ${DOCKER_TEST_IMAGE} .

docker-run-help-amd64: docker-image-amd64
	${DOCKER} run --rm --platform ${DOCKER_PLATFORM} --entrypoint /opt/mtproxy/mtproto-proxy ${DOCKER_TEST_IMAGE} 2>&1 | grep -q "Invoking engine"

tests: docker-run-help-amd64
	@echo "Tests passed: amd64 image builds and binary starts (--help)."

