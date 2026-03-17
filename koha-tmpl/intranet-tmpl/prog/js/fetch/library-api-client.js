import HttpClient from "../vue/fetch/http-client";

export class LibraryAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/libraries",
        });
    }

    get libraries() {
        return {
            getAll: (query, params, headers) =>
                this.getAll({
                    endpoint: "",
                    query,
                    params,
                    headers,
                }),
        };
    }
}

export default LibraryAPIClient;
