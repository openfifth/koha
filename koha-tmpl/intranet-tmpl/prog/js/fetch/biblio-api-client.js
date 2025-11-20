export class BiblioAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/biblios",
        });
    }

    get biblios() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "/" + id,
                    headers: {
                        ...headers,
                        Accept: "application/json",
                    },
                }),
        };
    }
}

export default BiblioAPIClient;
