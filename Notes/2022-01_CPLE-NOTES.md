
# Funness

bazel test --cache_test_results=no --test_output=all //test/e2e:session_discard_test

# Snippet
// namespace Cple {
// inline std::string str(const Time::SystemTime& time_point) {
//   std::time_t time = std::chrono::system_clock::to_time_t(time_point);
//   std::tm tm_object;
//   gmtime_r(&time, &tm_object);
//   char buffer[256];
//   std::strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S.", &tm_object);
//   return std::string{buffer};
// }
// } // namespace Cple

# Perforce

 * p4 edit <filename>
 * p4 revert <filename>
 * p4 sync cple/...
 * p4 opened

# Important files

+ ---------------------------------------------- + ----------------------------------------------- +
| test/e2e                                       | Look for a video                                |
| test/e2e/firewall_transaction_test.py          | The "1 smoke test"                              |
+ ---------------------------------------------- + ----------------------------------------------- +
| source/service/service_impl.cc                 | StartTransactionEvaluateFirewallCheckpoint 
| WDD_MDS_API/com/sed/wss/mds/v1/objects.proto   | `pre_expiry_check_secs`
| include/metadata/session_info/results_record.h |
+ ---------------------------------------------- + ----------------------------------------------- +
| tools/docker/cple_module/cple/configs/template/service/cple_service.json.jinja                   |
| cple/configs/dev_run_test.json                 | 


# Tickets

 * CPLE-27 - Fix "session_pre_expiry_offset_seconds"
 * CPLE-112 - Extend session can fall back to default...

# Info points

 * `expiry_time_utc`, and `pre_expiry_check_secs`. We're add an a configuration number of 
   seconds to these values.
 * Distinguish default/customer tenant
 * In `service_impl.cc`
   - Determine if we're managed at line#150, `if(cfs_entitlement != ...Entitled)`
   - When we determine we're managed.
   - If managed, about line#205, `STARUS_SESSION_CR(...)` we're creating a new session.
   - For firewall (CFS) transactions, there's a 1-1 relationship to sessions. 
     Not true in proxy world.
   - We then come up with an evaluation, at line#228, we're populating expiry info.
     (Look for `session->populateExpiryInfo`)
 * We need to change `populateExpiryInfo`.
   - We get a `results_record`, see `results_record.h`, `getExpiryTime()`
   - Add "preexpiry" info to the result records (preexpiry comes from MDS)
   - We need to be able to "calculate the expiry". See `session_impl.cc:220`, look for
     `auto calculateExpiry = ...`
   - MetadataResults already tells us if it's the "default tenant" or not.
   - If tenant is already expired, then we don't return an expiry time, but rather
     we return a gRPC call. See `session_impl.cc:258`... 
     look for `if (now >= results_record->getExpiryTime()`
     ~ This code is in `session_impl.cc:119:SessionImpl::extend`, look for where
       the call is to `populateExpiryInfo`. In this code we "change the expiry value"
        and send a response that the session is already expired.
   - If already expired, then we calculate the expiry time (see `session_impl.cc:270`)
     Currently we calculate on the expiry time, but we also have to use the
     preexpiry time as well.
   - The default-tenant has special logic: expiry time is current time plus some
     default value. The preexpiry is also in the config.
 * There's two places where there's configuration. It will be consolidated to one.
   - See `cple_service.json.jinja`
   - Section: `interchange_config`. This has the default, preexpiry, activity-linger.
     ~ `session_default_pre_expiry_offset_seconds`, but please use
       `session_default_pre_expiry_period_seconds`.
   - Add `session_pre_and_final_expiry_offset_seconds = 5`
   - This offset gets added to the preexpiry time, and the final expiry time.
   - Want to generate configuration from the jinja template. (Currently not doing this.)
     ~ The file is `cple/configs/dev_run_test.json`
     ~ The JSON reader for this file is: `cple/api/cple_config/v1/service_config.proto`
     ~ Update the proto file, and then update `dev_run_test.json` and the jinja template.
   - We will is this used in `session_impl.cc:239`, 
     look for `if (Metadata::SesssionInfo::isDefaultTenant(...)`
 * When we try to periodically extend the session... (CPLE-112)
   - We look for existing sessions, and extend it.
   - See `session_impl.cc:119`, look for `SessionImpl::extend`.
   
== CPLE-23 ==
 * Garbage collection loose sessions (CPLE-23)
   - If CFS goes away, when do we garbage collect the session out of cache.
   - There's an `activity_expiry_time`, and a `activity_check_timer`.
   - See `SessionImpl::SessionImpl`... 
   - An ASIO timer is set, and is calling back to `SessionImpl::activityCheckAndRefresh`
     every `activity_check_timer` seconds.
     ~ The timer is reenabled every time it fires, see: `activity_check_timer->enableTimer(...)`
   - Session is stopped if it is inactive
     ~ The session can also be discarded -- disposed when the last shared pointer is released.
   - We need to `queueDiscardSession` at the right place, so that the session is removed.
     Maybe in `SessionManagerImpl::createSession`, there's a function that calls the
     timer... see 35:48 in the video.
     ~ Note that we may have an atomic ++session_counter_ at the start of this function...
       and it should be a fetch-add.
     ~ This is where the `unlock` is.
     
# Possible thread errors

 * `session_discard_test`
   - read of size 1, 
   - write of size 1

# ======================================================================================= CPLE-27 ==
Action plan (https://jira.bde.broadcom.net/browse/CPLE-27?filter=-1)

 * Edit three files, to change configuration. (*TICK*)
   ~ `tools/docker/cple_module/cple/configs/template/service/cple_service.json.jinjap`
   ~ `configs/dev_run_test.json`
   ~ `api/cple_config/v1/service_config.proto`
   1. Change "interchange_config/session_pre_expiry_offset_seconds" to
             "interchange_config/default_session_pre_expiry_period_seconds".
   2. Add "interchange_config/session_pre_and_final_expiry_offset_seconds"

 * Edit these two files to get preexpriy from MDS. (*TICK*)
   ~ `include/metadata/session_info/results_record.h` (add virtual getPreExpiryTime)
   ~ `source/metadata/session_info/results_record_impl.h` (implement above.)
   Note: the protobuf message already has the preexpiry time.

* Edit `session_impl.cc`
   1. In `SessionImpl::populateExpiryInfo`, 
      ~ For "defaultTenants", we set calculate preexpiry from the configured value.
      ~ For "non-default-tenants", read the prexpiry time as is from the MDS data.
      ~ add our pre/final expiry offset seconds to the calculated expiry and preexpiry.

 * Israel + Shawn as reviews

cple_service: /home/BRCMLTD/am894222/Development/scorpius/project/cple/sg_cple1/src/common/util/fdt/bget_heap.cpp:1048: void FDT::BGet_heap::brel(void*): As
sertion `totalloc >= 0' failed.


source/interchange/session_impl.cc

test/interchange/session_impl_test.cc
test/metadata_default/session_info/results_record_utils_test.cc
test/mocks/metadata/session_info/mocks.h
source/metadata/session_info/results_record_impl.h
source/metadata_default/session_info/default_results_record_impl.h
include/metadata/session_info/results_record.h

tools/docker/cple_module/cple/configs/template/service/cple_service.json.jinja
api/cple_config/v1/service_config.proto
configs/dev_run_test.json


tools/docker/cple_module/cple/configs/template/service/cple_service.json.jinja
test/mocks/metadata/session_info/mocks.h

//scorpius/project/cple/sg_cple1/cple/api/cple_config/v1/service_config.proto#6 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/configs/dev_run_test.json#40 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/include/metadata/session_info/results_record.h#8 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/source/interchange/BUILD#7 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/source/interchange/session_impl.cc#9 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/source/metadata/session_info/results_record_impl.h#4 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/source/metadata_default/session_info/BUILD#2 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/source/metadata_default/session_info/default_results_record_impl.h#1 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/source/metadata_default/session_info/results_record_utils.h#2 - was delete, reverted
//scorpius/project/cple/sg_cple1/cple/test/e2e/firewall_transaction_test.py#36 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/test/interchange/session_impl_test.cc#5 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/test/metadata_default/session_info/BUILD#1 - was delete, reverted
//scorpius/project/cple/sg_cple1/cple/test/metadata_default/session_info/results_record_utils_test.cc#1 - was delete, reverted
//scorpius/project/cple/sg_cple1/cple/test/mocks/metadata/session_info/mocks.h#2 - was edit, reverted
//scorpius/project/cple/sg_cple1/cple/tools/docker/cple_module/cple/configs/template/service/cple_service.json.jinja#18 - was edit, reverted


# ======================================================================================= CPLE-27 ==
Action plan (https://jira.bde.broadcom.net/browse/CPLE-27?filter=-1)
  
   


