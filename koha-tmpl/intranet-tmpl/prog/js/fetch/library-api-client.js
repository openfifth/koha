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
            get: id =>
                this.httpClient.get({
                    endpoint: `/${id}`,
                }),
        };
    }
}

export default LibraryAPIClient;
