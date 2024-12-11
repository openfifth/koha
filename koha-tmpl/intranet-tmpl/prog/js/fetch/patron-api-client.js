export class PatronAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get patrons() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: "patrons/" + id,
                }),
        };
    }

    get categories() {
        return {
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "patron_categories",
                    query,
                    params,
                    headers,
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
