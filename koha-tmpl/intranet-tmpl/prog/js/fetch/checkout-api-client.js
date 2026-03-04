export class CheckoutAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get checkouts() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: "checkouts/" + id,
                    headers: {
                        "x-koha-embed": "item",
                    },
                }),
        };
    }
}

export default CheckoutAPIClient;
