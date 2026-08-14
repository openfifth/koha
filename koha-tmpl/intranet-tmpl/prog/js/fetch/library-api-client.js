/**
 * Client for library API operations.
 */
export class LibraryAPIClient {
    /**
     * Create a library API client.
     *
     * @param {Function} HttpClient HTTP client constructor.
     */
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    /**
     * Return library retrieval operations.
     *
     * @returns {Object} Library API operations.
     */
    get libraries() {
        return {
            /**
             * Fetch closed dates for a library.
             *
             * @param {string} library_id Library identifier.
             * @param {Object} [params] Closed-date query parameters.
             * @param {Object} [config] Per-request HTTP configuration.
             * @returns {Promise<string[]>} Closed calendar dates.
             */
            closed_dates: (library_id, params = {}, config) => {
                const query = new URLSearchParams(params).toString();
                return this.httpClient.get({
                    endpoint:
                        "libraries/" +
                        library_id +
                        "/closed_dates" +
                        (query ? "?" + query : ""),
                    config,
                });
            },
        };
    }
}

export default LibraryAPIClient;
