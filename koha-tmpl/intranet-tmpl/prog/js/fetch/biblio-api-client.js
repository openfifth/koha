export class BiblioAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get biblios() {
        return {
            getAll: (query, params) =>
                this.httpClient.getAll({
                    endpoint: "biblios",
                    query,
                    params,
                    headers: { Accept: "application/json" },
                }),
        };
    }

    get items() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: "biblios/" + id + "/items",
                }),
        };
    }
}

export default BiblioAPIClient;
