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
                    headers: {
                        "x-koha-embed":
                            "+strings,active_display,biblio,effective_bookable",
                    },
                }),
            getByExternalId: external_id =>
                this.httpClient.get({
                    endpoint:
                        "items?" +
                        new URLSearchParams({
                            _match: "starts_with",
                            _order_by: "me.barcode",
                            external_id: external_id,
                        }),
                    headers: {
                        "x-koha-embed":
                            "+strings,active_display,biblio,effective_bookable",
                    },
                }),
        };
    }

    get bundled_items() {
        return {
            add: (item_id, body, params = {}) =>
                this.httpClient.post({
                    endpoint: "items/" + item_id + "/bundled_items",
                    body,
                    ...params,
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
