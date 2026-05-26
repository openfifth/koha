export class ItemTypeAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
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

export default ItemTypeAPIClient;
