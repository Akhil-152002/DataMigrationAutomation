//=============================================================
// Flow Designer > Action/Flow > "Script" step
// Paste this in place of whatever calls Azure DevOps today.
// Map the fd_data.* references below to your actual Flow
// Designer data pill names for the catalog variables.
//=============================================================

var trigger = new AzureDevOpsPipelineTrigger();

var result = trigger.triggerPipeline({
    migrationStage:  'InitialCopy',
    businessReason:  fd_data.business_reason,
    sourcePath:      fd_data.source_path,
    requester:       fd_data.requester,
    email:           fd_data.email,
    destinationPath: fd_data.destination_path,
    migrationDate:   fd_data.migration_date,
    validationOwner: fd_data.validation_owner,
    businessUnit:    fd_data.business_unit,
    ritm:            fd_data.ritm_number,
    sctask:          fd_data.sctask_number
});

// Outputs to map in the Flow Designer step's output tab
outputs.success        = result.success;
outputs.status_code    = result.status_code;
outputs.response_body  = result.response_body;
outputs.message        = result.message;
