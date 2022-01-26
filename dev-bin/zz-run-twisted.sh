#!/bin/bash

set -euo pipefail

PPWD="$(cd "$(dirname "$0")" ; pwd -P)"
cd "$PPWD"

TMPD="$(mktemp -d /tmp/$(basename $0).XXXXXX)"
trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [OPTIONS...]*

   Options:

      --reboot-kb
      --force-orchestrate    Force the (re)creation of docker containers
      --twisted-tests
      --style-fix
      --bazel-test

      --fail-immediately     If an individual test fails, then stop running test cases.
      --continue-on-fail     Run all test cases even if one of them fails.

      --restart [always|unless-stopped|never]   This script uses a watch process to monitor
                             the kestrel container, and potentially restart it.

EOF
}

# 

# ---------------------------------------------------------------------------------------- Variables

LOG_DIR="/tmp/logs"

VERSION=latest
REBOOT_KB=false
ORCHESTRATE=false
ORCHESTRATE_ARG=""
TWISTED_TESTS=false
STYLE_FIX=false
BAZEL_TEST=false
BAZEL_ARGS="//test/..."
FAIL_IMMEDIATELY=false
THESE_TESTS=true

# If Kestrel quits, automagically reboot.
WATCH_CFS_ARG=always

ALL_ARGS="$*"

# ------------------------------------------------------------------------------- Parse Command Line

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "--reboot-kb" ]        && REBOOT_KB=true         && continue
    [ "$ARG" = "--skip-core-check" ]  && ORCHESTRATE_ARG="$ARG" && continue
    [ "$ARG" = "--orchestrate" ]      && ORCHESTRATE=true       && continue
    [ "$ARG" = "--no-orchestrate" ]   && ORCHESTRATE=false      && continue
    [ "$ARG" = "--twisted-tests" ]    && TWISTED_TESTS=true     && THESE_TESTS=false && continue
    [ "$ARG" = "--style-fix" ]        && STYLE_FIX=true         && THESE_TESTS=false && continue
    [ "$ARG" = "--fail-immediately" ] && FAIL_IMMEDIATELY=true  && continue
    [ "$ARG" = "--continue-on-fail" ] && FAIL_IMMEDIATELY=false && continue
    [ "$ARG" = "--restart" ]          && WATCH_CFS_ARG="$1"     && shift && continue

    [ "$ARG" = "--bazel-test" ] \
        && BAZEL_TEST=true      \
        && BAZEL_ARGS="$*"      \
        && THESE_TESTS=false    \
        && continue
    
    # We want to pass through additional arguments for bazel-tests
    if [ "$BAZEL_TEST" = "false" ] ; then
        echo "unexpected argument: $ARG"
        exit 1
    fi
done

valid_watch_cfs_args()
{
    cat <<EOF
always
unless-stopped
never
EOF
}

if ! valid_watch_cfs_args | grep -qE "^$WATCH_CFS_ARG\$" ; then
    echo "Invalid --restart argument: '$WATCH_CFS_ARG'" 1>&2
    exit 1
fi

# --------------------------------------------------------------------------------- Switch execution

# Move execution to linux server
HOSTNAME=$(hostname)
if [ "${HOSTNAME:0:7}" != "wac-usr" ] ; then
    kestrel-sync.sh
    ssh -t dev ". \$HOME/.bashrc ; \$KESTREL_GIT_DIR/zz-run.sh $ALL_ARGS" \
        && RET=0 || RET=1

    # If we did a "style fix" then copy back the results
    if [ "$RET" = "0" ] && [ "$STYLE_FIX" = "true" ] ; then
        rsync -azvc                                                 \
              "dev:$REMOTE_KESTREL_GIT_DIR/cfs/test/twisted_tests/" \
              "$PPWD/cfs/test/twisted_tests"
    fi
    if [ "$THESE_TESTS" = "true" ] ; then
        
        rsync -azvcq --no-times dev:$LOG_DIR/ $LOG_DIR --delete-after
    fi   
    exit "$RET"
fi

# Move exeuction (on linux server) into kb shell environment
env | grep -Eq '^USER=' && HAS_USER=true || HAS_USER=false
if [ "$HAS_USER" = true ] ; then
    export KESTREL_GIT_DIR="$HOME/sync/SWG_NGP_kestrel"
    cd "$PPWD"
    git submodule update --init --recursive
    echo
    echo "executing:     kb exec $(basename "$0") $ALL_ARGS"
    echo
    if [ "$REBOOT_KB" = "true" ] ; then
        kb stop
    fi
    kb exec echo kb container running
    docker cp ~/.ssh kestrel_build:/home/BRCMLTD/am894222
    docker cp ~/.docker kestrel_build:/home/BRCMLTD/am894222
    kb exec "./$(basename "$0") $ALL_ARGS" \
        && RET=0 || RET=1
    if [ "$THESE_TESTS" = "true" ] ; then
        docker cp kestrel_build:$LOG_DIR /tmp/
    fi   
    exit "$RET"
fi

# -------------------------------------------------------------------------------------- Environment
# The kestrel project; should be the same as KESTREL_GIT_DIR (if set)
cd "$PPWD"
SCRIPTS_DIR="$PPWD/cfs/test/scripts"

# ------------------------------------------------------------------------------------------ Action!

cat <<EOF
Action:

   TWISTED_TESTS:    $TWISTED_TESTS
   STYLE_FIX:        $STYLE_FIX
   BAZEL_TEST:       $BAZEL_TEST
   THESE_TESTS:      $THESE_TESTS

Configuration:

   REBOOT_KB:        $REBOOT_KB
   ORCHESTRATE:      $ORCHESTRATE
   FAIL_IMMEDIATELY: $FAIL_IMMEDIATELY

EOF

if [ "$TWISTED_TESTS" = "true" ] ; then
    make cfs_container
    cfs/test/scripts/run_twisted_tests.sh --force-orchestrate  --continue-on-fail
    exit $?
elif [ "$STYLE_FIX" = "true" ] ; then
    make style_fix
    exit $?
elif [ "$BAZEL_TEST" = "true" ] ; then
    bazel test $BAZEL_ARGS
    exit $?
fi


# Do the relevant docker containers exist
container_status()
{
    local CONTAINER="$1"
    # Is the container running? ('docker ps -a' shows stopped containers
    local STATUS="$(docker inspect -f '{{.State.Status}}' $CONTAINER 2>/dev/null || true)"
    if [ "$STATUS" = "" ] ; then
        echo "not found: '$CONTAINER'='$STATUS'"
    else
        echo "$STATUS"
    fi
}

check_containers()
{
    local SUCCESS=true
    for CONTAINER in kestrel_cfs_e2e kestrel_cfs_e2e_test_container kestrel_cfs_e2e_proxy_container
    do
        local STATUS="$(container_status "$CONTAINER")"
        echo "Docker container '$CONTAINER': $STATUS"
        if [ "$STATUS" != "running" ] ; then
            SUCCESS=false
        fi
    done    
    if [ "$SUCCESS" = false ] ; then
        echo "At least 1 required container is not running, re-orchestrating..."
        return 1
    fi
    return 0
}

if [ "$ORCHESTRATE" = "false" ] && check_containers
then   
    echo "Skipping orchestration step"
else
    "$SCRIPTS_DIR/dockers_up.sh" $ORCHESTRATE_ARG
fi

do_cfs_restart()
{
    echo -e "\n\e[33m(rebooting kestrel_cfs_e2e)\e[0m\n"
    docker restart -t 1 kestrel_cfs_e2e
}

watch_cfs_container()
{
    # Some testcases may want to restart Kestrel. They do this by posting:
    #
    #   curl -X POST localhost:8081/quitquitquit
    #
    # This will result in the kestrel container exiting. If we notice this,
    # we wait 1-2 seconds, and then reboot the container.
    while (( 1 )) ; do
        local CFS_STATUS="$(container_status kestrel_cfs_e2e)"
        if [ "$WATCH_CFS_ARG" = "never" ] || [ "$CFS_STATUS" = "running" ] ; then
            # All is good
            true
        elif [ "$WATCH_CFS_ARG" = "always" ] || [ "$CFS_STATUS" != "exited" ] ; then
            # Either WATCH_CFS_ARG = "always", and we always reboot
            # Or     WATCH_CFS_ARG = "unless-stopped", and CFS_STATUS isn't exited
            do_cfs_restart
        fi
        sleep 2
    done
}
watch_cfs_container &
WATCH_CFS_PID="$!"

print_tests()
{
cat <<EOF
# twisted_tests.connectivity.test_container                   
# twisted_tests.connectivity.test_management_interface        
# twisted_tests.docker_connectivity.test_docker_connectivity  
# twisted_tests.e2e.dummy_tcp_test                            

# twisted_tests.e2e.01_01_allow_traffic_test
# twisted_tests.e2e.01_02_drop_test                       
# twisted_tests.e2e.01_03_reject_test                     

# twisted_tests.e2e.02_01_no_grpc_cfs_cple_server_test        
# twisted_tests.e2e.02_02_grpc_cfs_cple_server_error_test 
# twisted_tests.e2e.02_03_boot_grpc_cfs_cple_server_test
    
# twisted_tests.e2e.03_unmanaged_cple_server_test

# twisted_tests.e2e.04_01_reevaluate_drop_test
# twisted_tests.e2e.04_02_reevaluate_proxy_bypass_test
# twisted_tests.e2e.04_03_reevaluate_bypass_proxy_test

# twisted_tests.e2e.05_01_preexpiry_expire_test                     
# twisted_tests.e2e.05_02_preexpiry_extend_test
# twisted_tests.e2e.05_03_preexpiry_in_past_test
# twisted_tests.e2e.05_04_extend_session_failure_retry_test

# twisted_tests.e2e.07_01_inactivity_timeout_test

twisted_tests.e2e.08_01_midflows_test

# twisted_tests.e2e.09_01_needs_dpi_at_request_test           
# twisted_tests.e2e.09_02_does_not_need_dpi_at_request_test   
# twisted_tests.e2e.09_03_allow_at_nc_drop_at_ci_test         
# twisted_tests.e2e.09_04_ci_retry_test                       
# twisted_tests.e2e.09_05_ci_retry_at_nc_failure_test         

# twisted_tests.e2e.10_other_protocol_test
EOF
}


# We save logs here:
LOG_DIR="/tmp/logs"
mkdir -p "$LOG_DIR"

# These temporary files accrue outputs that are
# used _after_ the testing while loop
OUTPUT_F="$LOG_DIR/zz-overall-output.text"
STATUS_CODE_F="$TMPD/status_code"
rm -f "$OUTPUT_F"
echo "0" > $STATUS_CODE_F

# The testing while loop... dynamically remove
# commented out tests
print_tests | grep -Ev '^#' | grep -Ev '^\s*$' | while read E2E_TEST ; do
    echo
    echo "Booting $E2E_TEST"

    # Kill the watch process... to avoid unnecessary feedback
    kill $WATCH_CFS_PID 2>/dev/null

    docker restart -t 1 kestrel_cfs_e2e_test_container
    docker restart -t 1 kestrel_cfs_e2e

    # Reboot the watch process
    watch_cfs_container &
    WATCH_CFS_PID="$!"
    
    # These are the log file names (testcase specific)
    KESTREL_LOG_FILE="$LOG_DIR/${E2E_TEST}.kestrel.log"
    STDOUT_LOG_FILE="$LOG_DIR/${E2E_TEST}.stdout.log"
    STDERR_LOG_FILE="$LOG_DIR/${E2E_TEST}.stderr.log"
    
    # Run the test with "line buffering" for stdout and stderr
    stdbuf --output=L --error=L                                         \
           docker exec kestrel_cfs_e2e_test_container trial $E2E_TEST   \
                    1> >(tee "$STDOUT_LOG_FILE")                        \
                    2> >(tee "$STDERR_LOG_FILE")                        \
        && SUCCESS=true || SUCCESS=false

    # Copy the kestrel log
    docker cp kestrel_cfs_e2e:/var/log/kestrel/current "$KESTREL_LOG_FILE"

    # Tell the end user where the log files are
    echo "Kestrel logs saved to: '$KESTREL_LOG_FILE'"
    echo "stdout saved to:       '$STDOUT_LOG_FILE'"
    echo "stderr saved to:       '$STDERR_LOG_FILE'"

    # Log SUCCESS/FAILURE 
    if [ "$SUCCESS" = true ] ; then
        echo -e "[\e[32m PASSED \e[0m] $E2E_TEST" >> $OUTPUT_F
    else
        echo -e "[\e[31m FAILED \e[0m] $E2E_TEST" >> $OUTPUT_F
        echo "1" > $STATUS_CODE_F
    fi

    # Exit early, if indicated
    if [ "$FAIL_IMMEDIATELY" = true ] && [ "$SUCCESS" = false ] ; then
        break
    fi
done

# Tell the user what happened in the testing loop
cat "$OUTPUT_F"
exit $(cat "$STATUS_CODE_F")



# --------------------------------------------------------------------------------------------------
# cple.flow.event.handler.active_allow_verdicts: 0
# cple.flow.event.handler.active_drop_verdicts: 0
# cple.flow.event.handler.active_flows: 0
# cple.flow.event.handler.active_flows_high_watermark: 1
# cple.flow.event.handler.active_reject_verdicts: 0
# cple.flow.event.handler.grpc.total_client_in_evaluations: 0
# cple.flow.event.handler.grpc.total_evaluate_stop_transactions: 1
# cple.flow.event.handler.grpc.total_extend_sessions: 2
# cple.flow.event.handler.grpc.total_failed_client_in_evaluations: 0
# cple.flow.event.handler.grpc.total_failed_evaluate_stop_transactions: 0
# cple.flow.event.handler.grpc.total_failed_extend_sessions: 0
# cple.flow.event.handler.grpc.total_failed_reevaluate_transactions: 0
# cple.flow.event.handler.grpc.total_failed_start_transaction_and_evaluate_new_connection_and_stop_transactions: 0
# cple.flow.event.handler.grpc.total_failed_start_transaction_and_evaluate_new_connections: 0
# cple.flow.event.handler.grpc.total_reevaluate_transactions: 0
# cple.flow.event.handler.grpc.total_request_validation_failures: 0
# cple.flow.event.handler.grpc.total_response_validation_failures: 2
# cple.flow.event.handler.grpc.total_start_transaction_and_evaluate_new_connection_and_stop_transactions: 0
# cple.flow.event.handler.grpc.total_start_transaction_and_evaluate_new_connections: 1
# cple.flow.event.handler.grpc.total_successful_client_in_evaluations: 0
# cple.flow.event.handler.grpc.total_successful_evaluate_stop_transactions: 1
# cple.flow.event.handler.grpc.total_successful_extend_sessions: 0
# cple.flow.event.handler.grpc.total_successful_reevaluate_transactions: 0
# cple.flow.event.handler.grpc.total_successful_start_transaction_and_evaluate_new_connection_and_stop_transactions: 0
# cple.flow.event.handler.grpc.total_successful_start_transaction_and_evaluate_new_connections: 1
# cple.flow.event.handler.total_allow_verdicts: 1
# cple.flow.event.handler.total_bypass_routes: 0
# cple.flow.event.handler.total_client_in_evaluation_failures: 0
# cple.flow.event.handler.total_deferred_client_in_evaluations: 0
# cple.flow.event.handler.total_deferred_reevaluations: 0
# cple.flow.event.handler.total_drop_verdicts: 0
# cple.flow.event.handler.total_expired_sessions: 0
# cple.flow.event.handler.total_failed_open_occurrences: 0
# cple.flow.event.handler.total_flows: 1
# cple.flow.event.handler.total_managed_cs_bytes: 360
# cple.flow.event.handler.total_managed_flows_closed_without_access_logs: 0
# cple.flow.event.handler.total_managed_sc_bytes: 235
# cple.flow.event.handler.total_new_flow_evaluation_failures: 0
# cple.flow.event.handler.total_protocol_result_events: 1
# cple.flow.event.handler.total_proxy_routes: 1
# cple.flow.event.handler.total_reevaluation_events: 0
# cple.flow.event.handler.total_reevaluation_failures: 0
# cple.flow.event.handler.total_reject_verdicts: 0
# cple.flow.event.handler.total_stop_transaction_evaluation_failures: 0
# cple.flow.event.handler.total_unmanaged_flows: 0
# cple.flow.event.handler.total_verdict_reversals: 0


