export class LibraryAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/libraries",
        });
    }

    get libraries() {
        return {
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "",
                    query,
                    params,
                    headers,
                }),
        };
    }
}

export default LibraryAPIClient;
