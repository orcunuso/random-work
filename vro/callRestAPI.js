var operationUrl = ("/api/Commands/SomeRESTMethod");
var requestType = "POST";
var body = {};
var retrycount = 5;
 
body["Param1"] = "Value1";
body["Param2"] = "Value2";
body["Param3"] = "Value3";
 
var requestContent = JSON.stringify(body);
var requestContentType = "application/json";
var request = att_resthost.createRequest(requestType, operationUrl, requestContent);
request.contentType = requestContentType;
request.setHeader("Authorization","Basic bWDuMMyP4ssW0rDsqAqwY2NQ==");
 
for (var i=1;i<retrycount+1;i++) {
    try {
        response = request.execute();
    } catch (e) {
        System.error(e);
        System.sleep(10000);
        continue;
    }
    strresponse = response.contentAsString;
    System.log("Response Status Code: " + response.statusCode);
    System.log("Content As String: " + strresponse);
     
    jsonresponse = JSON.parse(strresponse);
    System.log("Returned Data: " + jsonresponse.responseObject.data);
    if (jsonresponse.responseObject.data === "some value") {
        // Do something
    }
     break;
}
