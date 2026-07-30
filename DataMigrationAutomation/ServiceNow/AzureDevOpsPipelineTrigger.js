//=============================================================
// Script Include: AzureDevOpsPipelineTrigger
// Client callable: false
// Application: (your scope)
//
// PURPOSE
// Authenticates to Azure DevOps with a PAT stored as an
// encrypted system property, and queues a run of the
// Windows File Share Migration pipeline, passing through
// all the parameters defined in azure-pipelines.yml.
//
// SETUP (do this before using)
// 1. Create these System Properties (System Properties > All):
//      x_migration.azure_devops.org           -> JPMCDataMigrationGTI
//      x_migration.azure_devops.project        -> DataMigrationAutomation
//      x_migration.azure_devops.pipeline_id     -> <numeric pipeline id>
//      x_migration.azure_devops.branch          -> refs/heads/main  (or your default branch)
//      x_migration.azure_devops.pat             -> <the NEW rotated PAT>
//                                                    Type = Password (2 Way Encrypted)
//
//    To find pipeline_id: Azure DevOps > Pipelines > open the pipeline,
//    the ID is in the URL, e.g. .../_build?definitionId=42  -> 42
//
// 2. Confirm the PAT has scopes: Build (Read & Execute), Code (Read), Project (Read)
//
// 3. Test auth in isolation FIRST using the minimal GET-projects script
//    before relying on this script include, to confirm the PAT itself works.
//=============================================================

var AzureDevOpsPipelineTrigger = Class.create();

AzureDevOpsPipelineTrigger.prototype = {

    initialize: function() {},

    /**
     * Queues an Azure DevOps pipeline run.
     * @param {Object} params
     *   {
     *     migrationStage:  string  (default 'InitialCopy'),
     *     businessReason:  string,
     *     sourcePath:      string,
     *     requester:       string,
     *     email:           string,
     *     destinationPath: string,
     *     migrationDate:   string,
     *     validationOwner: string,
     *     businessUnit:    string,
     *     ritm:            string,
     *     sctask:          string
     *   }
     * @returns {Object} { success, status_code, response_body, message }
     */
    triggerPipeline: function(params) {

        var result = {
            success: false,
            status_code: null,
            response_body: null,
            message: ''
        };

        params = params || {};

        try {

            var org        = gs.getProperty('x_migration.azure_devops.org');
            var project     = gs.getProperty('x_migration.azure_devops.project');
            var pipelineId   = gs.getProperty('x_migration.azure_devops.pipeline_id');
            var branch      = gs.getProperty('x_migration.azure_devops.branch', 'refs/heads/main');
            var pat         = gs.getProperty('x_migration.azure_devops.pat');

            if (!org || !project || !pipelineId) {
                result.message = 'Missing one of: x_migration.azure_devops.org / .project / .pipeline_id system properties.';
                return result;
            }

            if (!pat) {
                result.message = 'Azure DevOps PAT is not configured in system property x_migration.azure_devops.pat.';
                return result;
            }

            var endpoint = 'https://dev.azure.com/' + org + '/' + project +
                '/_apis/pipelines/' + pipelineId + '/runs?api-version=7.1';

            var payload = {
                resources: {
                    repositories: {
                        self: {
                            refName: branch
                        }
                    }
                },
                templateParameters: {
                    MigrationStage:   params.migrationStage || 'InitialCopy',
                    BusinessReason:   params.businessReason || '',
                    SourcePath:       params.sourcePath || '',
                    Requester:        params.requester || '',
                    Email:            params.email || '',
                    DestinationPath:  params.destinationPath || '',
                    MigrationDate:    params.migrationDate || '',
                    ValidationOwner:  params.validationOwner || '',
                    BusinessUnit:     params.businessUnit || '',
                    RITM:             params.ritm || '',
                    SCTASK:           params.sctask || ''
                }
            };

            var rm = new sn_ws.RESTMessageV2();
            rm.setEndpoint(endpoint);
            rm.setHttpMethod('POST');
            rm.setRequestHeader('Content-Type', 'application/json');
            rm.setRequestHeader('Accept', 'application/json');

            // Basic auth: username is empty, password is the PAT.
            // RESTMessageV2 base64-encodes this into the Authorization header for you.
            rm.setBasicAuth('', pat);

            rm.setRequestBody(JSON.stringify(payload));

            var response = rm.execute();

            result.status_code = response.getStatusCode();
            result.response_body = response.getBody();

            result.success = (result.status_code >= 200 && result.status_code < 300);

            if (result.success) {
                result.message = 'Pipeline run queued successfully.';
            } else if (result.status_code == 203 || result.status_code == 302 ||
                       (result.response_body && result.response_body.indexOf('<!DOCTYPE html') === 0)) {
                result.message = 'Azure DevOps returned a sign-in page instead of JSON. ' +
                    'This means authentication failed: the PAT is invalid, expired, revoked, ' +
                    'or missing required scopes. Rotate the PAT and update the ' +
                    'x_migration.azure_devops.pat system property.';
            } else if (result.status_code == 401 || result.status_code == 403) {
                result.message = 'Azure DevOps rejected the PAT (unauthorized/forbidden). Check scopes and org access.';
            } else if (result.status_code == 404) {
                result.message = 'Pipeline not found. Check x_migration.azure_devops.pipeline_id, org, and project name.';
            } else {
                result.message = 'Azure DevOps returned status ' + result.status_code + '.';
            }

        } catch (ex) {
            result.message = ex.message;
        }

        return result;

    },

    type: 'AzureDevOpsPipelineTrigger'

};
