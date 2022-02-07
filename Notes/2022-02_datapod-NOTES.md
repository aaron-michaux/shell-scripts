
# --------------------------------------------------------------------------------------- 2022-02-03
@Yimei Zhang
Using "ipsec client" in a datapod, which contains a "concentrator"/proxy-sg, with Kestrel in between.
The traffic travels from IPSEC client
Concentrator passes the traffic to Kestrel CFS.

TCP traffic flow:
IPSEC client --> Cisco CSR --(IPSEC Tunnel)--> Kestrel CFS --> Proxy SG --> Internet

Customer on board:
Portal website: https://34.86.214.74/#policyConfig|cloudFirewall
Tenant ID --> login as customer --> configure firewall rules


For "extend session", we have test client and test server.
On the test server, we run this:
 > python3 /home/twisted/TwistedScripts/dp_echo_ip.py TCP
On the test client, we run this:
 > python3 -u TwistedScripts/do_get_ip_extend_session.py 35.190.181.8 7001

Tenant ID
WSS portol to onboard a customer (a company like Bank of America).
The customer has a "customer id" aka "tenant ID".
For example, in portal, you can see a customer kcfstb1-noauth-1 with tenant iD 105.
You then get entitled to products, for example, Kestrel.
Customers can have "Locations" (aka "Site"?) for configuring their traffic.
Can configure firewall rules: sources/desintations, services, verdicts, application overrides.

The concentrator assigns a NAT IP to the client.
https://bsg-confluence.broadcom.net/display/~Yimei_Zhang/Documentation+List
 * How to onboard a customer in portal.
   - (Search for "Portal" in Yimei's documentation list)
 * Deploy a datapod.
   - https://bsg-confluence.broadcom.net/display/~Yimei_Zhang/How+to+Deploy+a+Datapod+with+Kestrel+CFS+and+MDS+Support
 * Set up client
 * Send traffic from client to Internet via datapod (kestrel cfs)

 * There's a training video:
   - Get training video.
   - Yimei (Ee-may) to send the command.
   - What is the REPOs, for testing code.
     ~ Will send me the file two "TwistedScripts" files.
   - For IPSEC they only use session.tier-3, which means the concentrator will extend the session 720.
   - Yimei will send me her server credentials... she can configure the webserver to accept my traffic.
 
   Command to check Kestrel CFS and CPLE build:
   - docker exec -it containers_kestrel-cfs_1 more /kestrel/build_info.txt
   - docker exec -it containers_cple_service_1 more /cple/buildnumber
   The above is a Kestrel CFS training video for support team.   
   - https://drive.google.com/file/d/1UfVm_vS1YqvM4QOqZTs4m3PsDmv5KVUF/view?ts=61fac639


