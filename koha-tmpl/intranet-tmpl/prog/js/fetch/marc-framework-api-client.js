export class MarcFrameworkAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/cgi-bin/koha/services/itemrecorddisplay.pl",
        });
    }

    get frameworkMarcFields() {
        return {
            get: (params, headers) => {
                let endpoint = "?return_api_json=1";
                Object.entries(params).forEach(([key, value]) => {
                    endpoint += "&" + key + "=" + value;
                });
                return this.httpClient.get({
                    endpoint,
                });
            },
        };
    }
}

export default MarcFrameworkAPIClient;
