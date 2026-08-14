/**
 * Client for circulation-rule API operations.
 */
export class CirculationRulesAPIClient {
    /**
     * Create a circulation-rule API client.
     *
     * @param {Function} HttpClient HTTP client constructor.
     */
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    /**
     * Return circulation-rule retrieval operations.
     *
     * @returns {Object} Circulation-rule API operations.
     */
    get rules() {
        return {
            /**
             * Fetch circulation rules for a booking context.
             *
             * @param {Object} [params] Circulation-rule query parameters.
             * @param {Object} [config] Per-request HTTP configuration.
             * @returns {Promise<Object[]>} Matching circulation rules.
             */
            get: (params = {}, config) =>
                this.httpClient.get({
                    endpoint:
                        "circulation_rules?" +
                        new URLSearchParams(params).toString(),
                    config,
                }),
        };
    }
}

export default CirculationRulesAPIClient;
