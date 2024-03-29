
# Warnings
W_FLAGS:=-Wall -Wextra -Wpedantic -Winvalid-pch -Wnon-virtual-dtor -Wold-style-cast -Wcast-align -Wno-unused-parameter -Woverloaded-virtual -Wconversion -Wsign-conversion -Wnull-dereference -Wdouble-promotion -Wno-padded -Wformat-nonliteral -Wno-format-nonliteral -Wno-shadow -Wno-sign-conversion -Wno-conversion -Wno-cast-align -Wno-double-promotion -Wno-unused-but-set-variable -Wno-unused-variable -Werror
C_W_FLAGS:=-Wall -Wextra -Wpedantic -Winvalid-pch

# Debug, Release, Optimization 
D_FLAGS:=-DDEBUG_BUILD
R_FLAGS:=-DRELEASE_BUILD -DNDEBUG
O_FLAG:=-O3

# Compiling for debugging
GDB_FLAGS:=-g3 -gdwarf-2 -fno-omit-frame-pointer -fno-optimize-sibling-calls

# F_flags are for everything
C_F_FLAGS:=-fPIC -fvisibility=hidden -fdiagnostics-color=always -ferror-limit=4
F_FLAGS:=$(C_F_FLAGS) -fvisibility-inlines-hidden

# Sanitizer flags for tsan and usan only. (Not asan)
S_FLAGS:=-g -fno-omit-frame-pointer -fno-optimize-sibling-calls

# LTO
LTO_FLAGS:=-ffat-lto-objects
LTO_LINK:=-fuse-linker-plugin -flto

# asan
ASAN_FLAGS:=-g -DADDRESS_SANITIZE -fsanitize=address
ASAN_LINK:=-fsanitize=address

# usan
USAN_FLAGS:=-g -DUNDEFINED_SANITIZE -fsanitize=undefined
USAN_LINK:=-fsanitize=undefined

# tsan
TSAN_FLAGS:=-g -DTHREAD_SANITIZE -fsanitize=thread -fPIE
TSAN_LINK:=-fsanitize=thread -fPIE

# Coverage
COVERAGE_FLAGS:=-fprofile-instr-generate -fcoverage-mapping -fno-elide-constructors -fno-inline
COVERAGE_LINK:=-fprofile-instr-generate

