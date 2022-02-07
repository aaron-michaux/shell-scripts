
# --------------------------------------------------------------------------------------- 2022-01-28
@Ed Sweeney
@Rob Block
 * "SCAS" test environment.
   - "Super 'Crossbream' Automation System"; where "Crossbeam" is the company.
   - An orchestrator... mainly in Python
   - "Heavy lifting" happens in the testbed; SCAS is the orchestrator.
   - The testbed is in google cloud.
   - SCAS uses ssh and pexpect (python version of expect) to interact with google cloud.
 * "nping" to send traffic, a pit like "nc" -- a way to send TCP and IP traffic.
   - You don't have to have something running on the server... (???)

CPLE-CFS-SCAS roadmap
 - replicate CPLE request log, but putting trace line into grpc client.
   ~ Start with CPLE revision 20220121-1
   ~ CPLE image, kestrel CFS image, cfs-bundle piece (what's needed to configure CPLE.)
     The cfs image is cfg_scas_develop-20220119-1
 - convert twisted e2e "mock verdict map" to set the policy request to CPLE.
 - SCAS team does not have SALT to deploy the latest CPLE. This needs to be fixed.
   ~ CPLE will not deploy without a "SALT master".
 - Ed and Rob to provide testbed, where we can implement stuff independent of SCAS.
 - Map the existing twisted test orchestration environment to the SCAS testbed environment.
   ~ This involves wrapping the existing twisted test bash script in a script that
     takes source/destination IP addresses and subnet masks, etc., as parameters,
     and patches kestrel fastpath rules, etc., so that our script "just works".

Rob wants to start with the simplest twisted script. (See the
documentation: https://bsg-confluence.broadcom.net/pages/viewpage.action?pageId=442667618)

# Plan

CPLE-CFS-SCAS roadmap
 - replicate CPLE request log, but putting trace line into grpc client.
 - convert twisted e2e "mock verdict map" to set the policy request to CPLE.
 - SCAS team does not have SALT to deploy the latest CPLE. This needs to be fixed.
 - Ed and Rob to provide testbed, where we can implement stuff independent of SCAS.
 - Map the existing twisted test orchestration environment to the SCAS testbed environment.
   ~ This involves wrapping the existing twisted test bash script in a script that
     takes source/destination IP addresses and subnet masks, etc., as parameters,
     and patches kestrel fastpath rules, etc., so that our script "just works".

# SCAS Images

 Tal/Aaron, here are the images that we use with SCAS now.
CFS images: https://console.cloud.google.com/gcr/images/saasdev-sed-wss-proxysg/global/kestrel_cfs?orgonly=true&project=saasdev-sed-wss-proxysg&supportedpurview=project
CPLE images: https://console.cloud.google.com/gcr/images/saasdev-sed-wss-proxysg/global/cple_service?orgonly=true&project=saasdev-sed-wss-proxysg&supportedpurview=project
CPLE CFG bundle images: https://console.cloud.google.com/gcr/images/saasdev-sed-wss-proxysg/global/cple_cfg_bundle?orgonly=true&project=saasdev-sed-wss-proxysg&supportedpurview=project

We use these tags as the "last-known good" images prior to the CPLE changes for SALT.
 * kestrel_cfs: develop-20220120-1
 * cple_service: 20220121-1
 * cple_cfg_bundle: cfg_scas_develop-20220119-1

# Login
 * https://10.169.73.193/scas, aaron.michaux:anything
   log in with your email username (SCAS adds the @broadcom.com) to this SCAS server 
   which Ed and I use for CFS development (it uses a self-signed cert), We haven't yet 
   integrated SCAS with Okta - for now you can use any non-empty string as password.
 * Example run:
   https://10.169.73.193/scas//results/detail.php?id=20220201180223436762rob.black
   - Press Get Logs on any test to gain access to the Full Log for the run
   - The spool files show the interactions between SCAS and each test bed node.
     There is one spool file per ssh session (though requests that are suspended then 
     resumed will have multiple spool files per node).
   - To ssh into the CFS instance or the TEST_VM instance you must first log into a 
     SCAS server in the Waterloo lab that has access into GCP.  I'll deploy a SCAS server 
     for you to use that will have GCP access and will be more stable than the one Ed and I work on.
   - I configured a SCAS server for you to use for CFS work - it's in the Waterloo lab at.
     https://10.169.73.191/scas.
     ssh aaron@10.169.73.191 -- with the initial password the same as the username
     ssh tal@10.169.73.191 -- ibid

Here are links to runs I just started for you on 191:
Aaron: https://10.169.73.191/scas/results/detail.php?id=20220202152420939345aaron.michaux
Tal: https://10.169.73.191/scas/results/detail.php?id=20220202152143633196tal.nordon
Once they have deployed you will see the TEST_VM address at the top of the page.  At that point you can ssh to the TEST_VM from your SCAS server (191).  I will send you the passwords for the TEST_VM in Google chat.  The "scas" account on the TEST_VM has sudo privileges.  (There is no need for personalized logins on the TEST_VM - just ssh in as "scas").

   autossh scas@test-vm-ip-addres, password is son*net

NOTE: The SCAS UI does not refresh automatically (it's in the backlog to fix some day).  So to get a fresh view of your request you'll have to Refresh the browser.

Stepping away for a short time.  If you need any help just let me or Ed know.

Tal, I fixed my typo in your SCAS username (sorry about that).  I started a new run using your correct SCAS username:

FYI the password for ssh'ing into your TEST_VM is son*net.   I mentioned the username in the email I sent just now.

