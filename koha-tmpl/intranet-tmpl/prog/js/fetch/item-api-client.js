export class ItemAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get items() {
        return {
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "items",
                    query,
                    params,
                    headers,
                }),
            get: id =>
                this.httpClient.get({
                    endpoint: "items/" + id,
                }),
            getByExternalId: external_id =>
                this.httpClient.get({
                    endpoint: "items?" +
                    new URLSearchParams({
                        _match: 'starts_with',
                        external_id: external_id,
                    }),
                }),
        };
    }

    get item_types() {
        return {
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "item_types",
                    query,
                    params,
                    headers,
                }),
        };
    }
}

export default ItemAPIClient;
