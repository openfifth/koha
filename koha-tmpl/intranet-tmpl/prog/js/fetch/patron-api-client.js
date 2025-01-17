export class PatronAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/patrons/",
        });
    }

    get patrons() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: id,
                }),
        };
    }

    get userPermissions() {
        return {
            get: () =>
                this.httpClient.get({
                    endpoint: "user_permissions",
                }),
        };
    }
}

export default PatronAPIClient;
