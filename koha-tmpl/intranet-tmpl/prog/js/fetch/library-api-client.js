export class LibraryAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get libraries() {
        return {
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "libraries",
                    query,
                    params,
                    headers,
                }),
        };
    }
}

export default LibraryAPIClient;
