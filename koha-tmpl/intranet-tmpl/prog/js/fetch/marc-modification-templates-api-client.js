export class MARCModificationTemplatesAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/marc_modification_templates",
        });
    }

    get marc_modification_templates() {
        return {
            get: id => this.httpClient.get({ endpoint: "/" + id }),
            getAll: (query, params) =>
                this.httpClient.getAll({
                    endpoint: "",
                    query,
                    params,
                    headers: {},
                }),
        };
    }
}

export default MARCModificationTemplatesAPIClient;
