//import ballerina/http;
import ballerina/log;
import ballerinax/googleapis.sheets as sheets;
import ballerinax/salesforce as sfdc;
import ballerinax/trigger.salesforce as sfdcListener;

type GsheetCellValueType int|string|decimal;

type GSheetOAuth2Config record {
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl = "https://www.googleapis.com/oauth2/v3/token";
};

type SalesforceOAuth2Config record {
    string clientId;
    string clientSecret;
    string refreshToken;
    string refreshUrl = "https://login.salesforce.com/services/oauth2/token";
};

// Salesforce listener configuration parameters
type ListenerConfig record {
    string username;
    string password;
};

// Constants
const string CHANNEL_PREFIX = "/data/";
const string EVENT_POSTFIX = "ChangeEvent";
const string BASE_URL = "/services/data/v48.0/sobjects/";
const int HEADINGS_ROW = 1;

configurable ListenerConfig salesforceListenerConfig = ?;
configurable SalesforceOAuth2Config salesforceOAuthConfig = ?;
configurable string salesforceBaseUrl = ?;
configurable string salesforceObject = ?;

configurable GSheetOAuth2Config GSheetOAuthConfig = ?;
configurable string spreadsheetId = ?;
configurable string worksheetName = ?;

listener sfdcListener:Listener sfdcEventListener = new ({
    username: salesforceListenerConfig.username,
    password: salesforceListenerConfig.password,
    channelName: CHANNEL_PREFIX + salesforceObject + EVENT_POSTFIX
});

@display {label: "Salesforce New Record to Google Sheets Row"}
service sfdcListener:RecordService on sfdcEventListener {
    remote function onCreate(sfdcListener:EventData payload) {
        log:printInfo("New record created ####### tested", payload = payload);
        string sobjectId = payload?.metadata?.recordId ?: "";

        do {
            sfdc:Client sfdcClient = check new ({
                baseUrl: salesforceBaseUrl,
                auth: {
                    clientId: salesforceOAuthConfig.clientId,
                    clientSecret: salesforceOAuthConfig.clientSecret,
                    refreshToken: salesforceOAuthConfig.refreshToken,
                    refreshUrl: salesforceOAuthConfig.refreshUrl
                }
            });
            log:printInfo("Retriving Record", payload = sobjectId);
            record {}|error res = sfdcClient->getById("Lead", sobjectId);

            string[] columnNames = [];
            GsheetCellValueType[] values = [];
            log:printInfo("Retriving ###");
            if res is record {} {
                // Iterate over all fields in the record
                log:printInfo("Iterating over the fields of the Salesforce record");
                foreach var [key, value] in res.entries() {
                    log:printInfo("####");
                    log:printInfo("Field: " + key + ", Value: " + value.toString());
                    columnNames.push(key);
                    values.push(value.toString());
                }
            } else {
                log:printError("Error while fetching Salesforce record", err = res.message());
            }

            log:printInfo("Connecting Google Sheet via client #1");

            sheets:Client|error gSheetClientResult = new ({
                auth: {
                    clientId: GSheetOAuthConfig.clientId,
                    clientSecret: GSheetOAuthConfig.clientSecret,
                    refreshToken: GSheetOAuthConfig.refreshToken,
                    refreshUrl: GSheetOAuthConfig.refreshUrl
                }
            });

            if (gSheetClientResult is sheets:Client) {
                log:printInfo("Connecting to Google Sheets successfully #2");

                sheets:Row|error headersResult = gSheetClientResult->getRow(spreadsheetId, worksheetName, HEADINGS_ROW);
                if (headersResult is sheets:Row) {
                    sheets:Row headers = headersResult;
                    log:printInfo("Creating GR ####### #1", payload = payload);
                    if headers.values.length() == 0 {
                        check gSheetClientResult->appendRowToSheet(spreadsheetId, worksheetName, columnNames);
                        log:printInfo("Creating GR ####### #2", payload = payload);
                    }

                    check gSheetClientResult->appendRowToSheet(spreadsheetId, worksheetName, values);
                    log:printInfo(string `${salesforceObject} with Id ${sobjectId} added to spreadsheet successfully`);
                } else {
                    log:printError("Error retrieving headers from Google Sheets", err = headersResult.message());
                }
            } else {
                log:printError("Error connecting to Google Sheets", err = gSheetClientResult.message());
            }

        } on fail var e {

            log:printError("Error while fetching Salesforce record", err = e.message());
            return;
        }

    }

    remote function onDelete(sfdcListener:EventData payload) returns error? {
        return;
    }

    remote function onRestore(sfdcListener:EventData payload) returns error? {
        return;
    }

    remote function onUpdate(sfdcListener:EventData payload) returns error? {
        return;
    }
}

//service /ignore on new http:Listener(8090) {}
