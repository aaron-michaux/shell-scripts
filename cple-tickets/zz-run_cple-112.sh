#!/bin/bash

SCRIPT="$(basename "$0")"
SRCD="$(cd "$(dirname "$0")" ; pwd)"
DSTD=/home/BRCMLTD/am894222/Development/scorpius/project/cple/sg_cple1/cple
[ "$(hostname)" = "wac-usr-136-169" ] && IS_BRCMLTD=1 || IS_BRCMLTD=0

STYLE_FIX=false
REBOOT_KB=true
env | grep -Eq '^USER=' && HAS_USER=true || HAS_USER=false

TMPD="$(mktemp -d "$(basename $0).XXXXXX")"
trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}

edit_list()
{
    cat <<EOF
source/interchange/session_impl.cc
source/interchange/session_impl.h
include/interchange/session.h
EOF
}

delete_list()
{
    cat <<EOF
EOF
}

sync_files()
{
    FILE_LIST="$TMPD/file-list.text"
    edit_list > "$FILE_LIST"
    echo "$SCRIPT" >> "$FILE_LIST"
    A="$1"
    B="$2"
    rsync -azvcth --no-times --files-from "$FILE_LIST" \
          "$A" "$B"
}

do_style_fix()
{
    if [ "$IS_BRCMLTD" = "0" ] ; then     # On MacOs
        # Sync files
        ! sync_files "$SRCD" "dev:$DSTD" && exit 1

        # Move execution to Linux server
        ssh -t dev ". \$HOME/.bashrc ; $DSTD/$SCRIPT" && RET=0 || RET=1

        # If we did a "style fix" then copy back the results
        if [ "$RET" = "0" ] ; then
            sync_files "dev:$DSTD" "$SRCD"
        fi

        exit $RET

    elif [ "$HAS_UER" = true ] ; then     # On Linux
        echo
        echo "executing:     kb exec ./$(basename "$0") $ALL_ARGS"
        echo
        if [ "$REBOOT_KB" = "true" ] ; then
            kb stop
        fi
        cple-kb.sh make style_fix
        exit $?        
    fi
}

sync_edit_list_to_linux()
{
    if [ "$IS_BRCMLTD" = "0" ] ; then     # On MacOs
        find "$SRCD" -type f -name '*.cc' -o -name '*.h' -o -name "BUILD" | while read L ; do \
            chmod 644 "$L"
        done
        
        scp "$SRCD/$SCRIPT" "dev:$DSTD/$SCRIPT"
        
        # Move execution to Linux server
        ssh -t dev ". \$HOME/.bashrc ; $DSTD/$SCRIPT" && RET=0 || RET=1

        # Push files to Linux
        sync_files "$SRCD" "dev:$DSTD"
        
    elif [ "$HAS_USER" = true ] ; then     # On Linux
        
        # Revert files
        cd "$DSTD/.."
        p4 revert cple/...
        cd cple

        # Iterate through delete list
        delete_list | grep -Ev '#' | grep -Ev '^$' | while read L ; do
            echo p4 delete "$L"
            p4 delete "$L"
        done

        # Iterate through edit list
        edit_list | grep -Ev '#' | while read L ; do
            echo p4 edit "$L"
            p4 edit "$L"
        done
        
    fi
}

# ------------------------------------------------------------------------------------------- Action

if [ "$STYLE_FIX" = "true" ] ; then
    do_style_fix
    exit $?

else
    sync_edit_list_to_linux
    exit $?
fi

# --------------------------------------------------------------------------------------------- Plan

exit 0

cat <<EOF

NOTE: This ticket may not be necessary, because
@Shawn We only revert to default during the initial starting of the
       transaction. I'd expect we'd just continue to use the existing expiry
       time of the session info we last have from cache. In a meeting, there
       was a statement that MDS wouldn't be offline for more than the
       pre-expiry to expiry time (ie. as long the agent tries at both the
       pre-expiry and expiry times to extend, we should get the session
       extended if it's valid)
          https://bsg-confluence.broadcom.net/display/SWG/User+Info+logic 
       has the note from our side that there is no need to artificially extend
       the the info - just need to verify returning back the current expiry
       info will have Kestrel retry a second time before the expiry.

Edit: source/interchange/session_impl.h
 * Add boolean member: `bool mds_available_at_last_refresh_{false}`

Edit: source/interchange/session_impl.cc:refreshMetadataResults
 * At top of funciton, 
      mds_available_at_last_refresh_ = true; // unless proven otherwise
 * Currently returns TRUE even when MDS is down. That is, there's a "TODO: add stat "
   at line #101; which is what "executes" when MDS is down, and this falls through.
      mds_available_at_last_refresh_ = false; 

Edit: source/interchange/session_impl.cc:extend
 * Change the fail condition:
   if (!refreshMetadataResults() && mds_available_at_last_refresh_) {
      return false;
   }

Edit: source/interchange/session_impl.cc:populateExpiryInfo
 * Add `use_default_tenant` variable 
     const bool use_default_tenant = is_default_tenant || !mds_available_at_last_refresh_
 * At line #259, change condition:
   if (use_default_tenant) { ...

EOF




