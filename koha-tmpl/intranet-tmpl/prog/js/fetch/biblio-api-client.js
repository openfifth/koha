export class BiblioAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get items() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: "biblios/" + id + "/items",
                }),
        };
    }

    get biblios() {
        return {
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "biblios",
                    query,
                    params,
                    headers: {
                        Accept: "application/json",
                        ...headers,
                    },
                }),
            get: id =>
                this.httpClient.get({
                    endpoint: "biblios/" + id,
                    headers: {
                        Accept: "application/json",
                    },
                }),
        };
    }
}

export default BiblioAPIClient;
