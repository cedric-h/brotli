CC=clang --target=wasm32 -ffreestanding -nostdlib
OS := $(shell uname)
LIBSOURCES = $(wildcard c/common/*.c) $(wildcard c/enc/*.c)
SOURCES = $(LIBSOURCES)
BINDIR = bin
OBJDIR = $(BINDIR)/obj
LIBOBJECTS = $(addprefix $(OBJDIR)/, $(LIBSOURCES:.c=.o))
OBJECTS = $(addprefix $(OBJDIR)/, $(SOURCES:.c=.o))
LIB_A = libbrotli.a
EXECUTABLE = smol.wasm
DIRS = $(OBJDIR)/c/common $(OBJDIR)/c/enc $(BINDIR)/tmp
CFLAGS += -O3 -isystem ced_crt -mbulk-memory
ifeq ($(os), Darwin)
  CPPFLAGS += -DOS_MACOSX
endif

ifneq ($(strip $(CROSS_COMPILE)), )
	CC=$(CROSS_COMPILE)-gcc
	ARCH=$(firstword $(subst -, ,$(CROSS_COMPILE)))
	BROTLI_WRAPPER="qemu-$(ARCH) -L /usr/$(CROSS_COMPILE)"
endif

# The arm-linux-gnueabi compiler defaults to Armv5. Since we only support Armv7
# and beyond, we need to select Armv7 explicitly with march.
ifeq ($(ARCH), arm)
	CFLAGS += -march=armv7-a -mfloat-abi=hard -mfpu=neon
endif

all: test
	@:

.PHONY: all clean test

$(DIRS):
	mkdir -p $@

$(EXECUTABLE): $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) \
    -flto \
    -Wl,--no-entry \
    -Wl,--allow-undefined \
    -Wl,--export=__heap_base \
    -Wl,--export=BrotliEncoderCompress \
    -Wl,--export=BrotliEncoderMaxCompressedSize \
    -o $(BINDIR)/$(EXECUTABLE)

lib: $(LIBOBJECTS)
	rm -f $(LIB_A)
	ar -crs $(LIB_A) $(LIBOBJECTS)

test: $(EXECUTABLE)
	tests/compatibility_test.sh $(BROTLI_WRAPPER)
	tests/roundtrip_test.sh $(BROTLI_WRAPPER)

clean:
	rm -rf $(BINDIR) $(LIB_A)

.SECONDEXPANSION:
$(OBJECTS): $$(patsubst %.o,%.c,$$(patsubst $$(OBJDIR)/%,%,$$@)) | $(DIRS)
	$(CC) $(CFLAGS) $(CPPFLAGS) -Ic/include \
        -c $(patsubst %.o,%.c,$(patsubst $(OBJDIR)/%,%,$@)) -o $@
