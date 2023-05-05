
# To build a system header
$(GCM_DIR)/$(CPPLIB_DIR)/%.gcm: | ensure_gcm_link
	@echo "$(BANNER)c++-system-header $(basename $(notdir $@))$(BANEND)"
	$(CXX) -x c++-system-header $(CXXFLAGS_F) $(basename $(notdir $@))
	@$(RECIPETAIL)

ALL_SYS_HEADERS:=$(shell find $(CPPLIB_DIR) -maxdepth 1 -type f ! -name '*.h' | sed 's,$(CPPLIB_DIR)/,,')
ALL_SYS_GCMS:=$(patsubst %, $(GCM_DIR)/$(CPPLIB_DIR)/%.gcm, $(ALL_SYS_HEADERS))

# The system header rules
.PHONY: $(ALL_SYS_HEADERS) all_cpp_headers
all_cpp_headers: $(ALL_SYS_GCMS)
iostream: $(GCM_DIR)/$(CPPLIB_DIR)/iostream.gcm
string: $(GCM_DIR)/$(CPPLIB_DIR)/string.gcm
vector: $(GCM_DIR)/$(CPPLIB_DIR)/vector.gcm
set: $(GCM_DIR)/$(CPPLIB_DIR)/set.gcm

