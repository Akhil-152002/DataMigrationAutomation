//=============================================================
// Run this in Scripts - Background (or a Flow Designer Script
// step temporarily) FIRST, before touching AzureDevOpsPipelineTrigger.
// Confirms whether the PAT itself is the problem.
//=============================================================

(function() {

    var endpoint = "https://dev.azure.com/JPMCDataMigrationGTI/DataMigrationAutomation/_apis/projects?api-version=7.1";

    // Paste the NEW rotated PAT here temporarily for this isolated test only.
    // Do not leave it hardcoded once the test is done.
    var pat = "YOUR_NEW_PAT";

    var rm = new sn_ws.RESTMessageV2();
    rm.setEndpoint(endpoint);
    rm.setHttpMethod("GET");
    rm.setRequestHeader("Accept", "application/json");
    rm.setBasicAuth("", pat);

    var response = rm.execute();

    gs.info("STATUS: " + response.getStatusCode());
    gs.info("BODY: " + response.getBody());

})();
