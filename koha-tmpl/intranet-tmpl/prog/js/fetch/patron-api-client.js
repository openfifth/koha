export class PatronAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/patrons/",
        });
    }

    get patrons() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: id,
                }),
            getPermittedPatrons: (query, params) =>
                this.get({
                    endpoint: "permitted_patrons",
                    query,
                    params,
                }),
        };
    }
}

export default PatronAPIClient;
