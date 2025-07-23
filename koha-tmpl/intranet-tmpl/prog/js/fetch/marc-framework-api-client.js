export class MarcFrameworkAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/cgi-bin/koha/services/itemrecorddisplay.pl",
        });
    }

    get frameworkMarcFields() {
        return {
            get: (frameworkcode, headers) =>
                this.httpClient.getAll({
                    endpoint: "?return_json=1&frameworkcode=" + frameworkcode,
                }),
        };
    }
}

export default MarcFrameworkAPIClient;
