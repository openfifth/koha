export class ItemGroupAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    list(biblio_id) {
        return this.httpClient.get({
            endpoint: "biblios/" + biblio_id + "/item_groups",
        });
    }
}

export default ItemGroupAPIClient;
