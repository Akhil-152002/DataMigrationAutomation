# Setup order

## Why the 203/HTML error happened
The zip you originally shared only contains the Azure DevOps repo (pipeline YAML +
PowerShell scripts that run *after* the pipeline is already queued). The actual
call that authenticates to Azure DevOps and queues the pipeline run lives in
**ServiceNow**, and it wasn't in that zip. That call is what's failing — Azure
DevOps is responding with its sign-in HTML page, meaning the PAT it received
was invalid, expired, revoked, or lacked scope.

## Steps, in order

1. **Rotate the PAT** in Azure DevOps (User Settings > Personal Access Tokens).
   Scopes: Build (Read & Execute), Code (Read), Project (Read). The old one
   (`AmBP3EQW...`) was pasted in a chat, treat it as compromised regardless.

2. **Run `AuthTest_ScriptsBackground.js`** in ServiceNow's Scripts - Background,
   with the new PAT pasted in temporarily. Confirm you get a `200` with JSON
   back, not `203` with HTML. Don't move on until this passes.

3. **Create the system properties** listed at the top of
   `AzureDevOpsPipelineTrigger.js`:
   - `x_migration.azure_devops.org`
   - `x_migration.azure_devops.project`
   - `x_migration.azure_devops.pipeline_id` (numeric ID from the pipeline's URL)
   - `x_migration.azure_devops.branch`
   - `x_migration.azure_devops.pat` — type **Password (2 Way Encrypted)**, paste
     the new PAT here. Never hardcode it in a script.

4. **Create the Script Include** `AzureDevOpsPipelineTrigger` using the code in
   `AzureDevOpsPipelineTrigger.js`. Client callable = false.

5. **Update the Flow Designer script step** that queues the pipeline to match
   `FlowDesigner_ScriptStep.js` — call the Script Include instead of whatever
   inline REST call is there today, and map `fd_data.*` to your actual catalog
   variable data pill names.

6. **Deploy `azure-pipelines.yml`** and the updated `scripts/GetRequest.ps1`
   to the Azure DevOps repo (overwrite what's there). `GetRequest.ps1` now
   builds the request object from the real pipeline parameters instead of
   reading a mock local JSON file — that mock read only worked for local
   testing and would never reflect what ServiceNow sends.

7. Submit a test catalog request end to end and check the flow's output vars
   (`status_code`, `response_body`, `message`) — you should see `200` and a
   JSON body with a `run` id.

## Before your next manual test run

The pipeline writes everything to `C:\Migration\...` on the agent machine
(logs, reports, archive, and now the persistent request-state file). On the
agent machine itself, create these once, as an account with rights to write
there:

```powershell
New-Item -ItemType Directory -Path `
  "C:\Migration\Logs", `
  "C:\Migration\Reports", `
  "C:\Migration\Archive", `
  "C:\Migration\Output", `
  "C:\Migration\Requests" `
  -Force
```

If the agent's service account can't create folders at `C:\` root itself,
"Get Migration Request" will fail almost immediately (as seen in your last
run) because its very first action, `Initialize-Log`, tries to create
`C:\Migration\Logs`.

Also make sure your test `Source` and `Destination` values (whatever you
type into the manual "Run pipeline" parameters) point to folders that
actually exist on that same agent machine — `Validate.ps1`/`InitialCopy.ps1`
will fail otherwise.

## One assumption to double check
In `GetRequest.ps1`, `BusinessOwner` is mapped from your `ValidationOwner`
catalog variable, since there's no separate "business owner" field in the
catalog data you shared. If that's wrong, tell me the correct source field
and I'll adjust the mapping.
