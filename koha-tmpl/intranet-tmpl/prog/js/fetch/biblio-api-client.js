export class BiblioAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get biblios() {
        return {
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "biblios",
                    query,
                    params,
                    headers,
                }),
            get: id =>
                this.httpClient.get({
                    endpoint: "items/" + id,
                }),
        };
    }
}

export default BiblioAPIClient;
