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

    get item_biblio_links() {
        return {
            // Both calls return the raw Response so the caller can act on the
            // 409 conflicts (duplicate link, same record, holds exist)
            create: ({ biblio_id, item_id, link_type }) =>
                this.httpClient.post({
                    endpoint: "biblios/" + biblio_id + "/item_biblio_links",
                    body: { item_id, link_type },
                    return_response: true,
                }),
            delete: ({ biblio_id, item_biblio_link_id, force }) =>
                this.httpClient.delete({
                    endpoint:
                        "biblios/" +
                        biblio_id +
                        "/item_biblio_links/" +
                        item_biblio_link_id +
                        (force ? "?force=1" : ""),
                }),
        };
    }
}

export default BiblioAPIClient;
