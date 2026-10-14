export class RecordMatchersAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/record_matchers",
        });
    }

    get record_matchers() {
        return {
            get: id => this.httpClient.get({ endpoint: "/" + id }),
            getAll: (query, params) =>
                this.httpClient.getAll({
                    endpoint: "",
                    query,
                    params,
                    headers: {},
                }),
        };
    }
}

export default RecordMatchersAPIClient;
