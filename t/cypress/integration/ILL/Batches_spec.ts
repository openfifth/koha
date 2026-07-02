const pubmedid_metadata_response = {
    errors: [],
    results: {
        result: {
            header: {
                type: "esummary",
                version: "0.3",
            },
            result: {
                "123": {
                    articleids: [
                        {
                            idtype: "pubmed",
                            idtypen: 1,
                            value: "123",
                        },
                        {
                            idtype: "doi",
                            idtypen: 3,
                            value: "10.1002\/bjs.1800621024",
                        },
                    ],
                    attributes: ["Has Abstract"],
                    authors: [
                        {
                            authtype: "Author",
                            clusterid: "",
                            name: "Keighley MR",
                        },
                        {
                            authtype: "Author",
                            clusterid: "",
                            name: "Asquith P",
                        },
                        {
                            authtype: "Author",
                            clusterid: "",
                            name: "Edwards JA",
                        },
                        {
                            authtype: "Author",
                            clusterid: "",
                            name: "Alexander-Williams J",
                        },
                    ],
                    availablefromurl: "",
                    bookname: "",
                    booktitle: "",
                    chapter: "",
                    doccontriblist: [],
                    docdate: "",
                    doctype: "citation",
                    edition: "",
                    elocationid: "",
                    epubdate: "",
                    essn: "",
                    fulljournalname: "The British journal of surgery",
                    history: [
                        {
                            date: "1975\/10\/01 00:00",
                            pubstatus: "pubmed",
                        },
                        {
                            date: "1975\/10\/01 00:01",
                            pubstatus: "medline",
                        },
                        {
                            date: "1975\/10\/01 00:00",
                            pubstatus: "entrez",
                        },
                    ],
                    issn: "0007-1323",
                    issue: "10",
                    lang: ["eng"],
                    lastauthor: "Alexander-Williams J",
                    locationlabel: "",
                    medium: "",
                    nlmuniqueid: "0372553",
                    pages: "845-9",
                    pmcrefcount: "",
                    pubdate: "1975 Oct",
                    publisherlocation: "",
                    publishername: "",
                    pubstatus: "4",
                    pubtype: ["Journal Article"],
                    recordstatus: "PubMed - indexed for MEDLINE",
                    references: [],
                    reportnumber: "",
                    sortfirstauthor: "Keighley MR",
                    sortpubdate: "1975\/10\/01 00:00",
                    sorttitle:
                        "importance of an innervated and intact antrum and pylorus in preventing postoperative duodenogastric reflux and gastritis",
                    source: "Br J Surg",
                    srccontriblist: [],
                    srcdate: "",
                    title: "The importance of an innervated and intact antrum and pylorus in preventing postoperative duodenogastric reflux and gastritis.",
                    uid: "123",
                    vernaculartitle: "",
                    volume: "62",
                },
                uids: ["123"],
            },
        },
    },
};

const parse_to_ill_response = {
    errors: [],
    results: {
        result: {
            article_title:
                "The importance of an innervated and intact antrum and pylorus in preventing postoperative duodenogastric reflux and gastritis.",
            associated_id: "123",
            author: "Keighley MR; Asquith P; Edwards JA; Alexander-Williams J",
            issn: "0007-1323",
            issue: "10",
            pages: "845-9",
            publisher: "",
            pubmedid: "123",
            title: "The British journal of surgery",
            volume: "62",
            year: "1975",
        },
    },
};

const batchstatuses = [
    {
        code: "NEW",
        id: 1,
        is_system: true,
        name: "New",
    },
    {
        code: "IN_PROGRESS",
        id: 2,
        is_system: true,
        name: "In progress",
    },
    {
        code: "COMPLETED",
        id: 3,
        is_system: true,
        name: "Completed",
    },
    {
        code: "UNKNOWN",
        id: 4,
        is_system: true,
        name: "Unknown",
    },
];

describe("ILL Batches", () => {
    beforeEach(() => {
        cy.login();
        cy.task("query", {
            sql: "SELECT value FROM systempreferences WHERE variable='ILLModule'",
        }).then(rows => {
            cy.wrap(rows[0].value).as("syspref_ILLModule");
        });
        cy.set_syspref("ILLModule", 1);
        cy.title().should("eq", "Koha staff interface");
        cy.get("a.icon_administration").contains("Administration").click();
        cy.get("a").contains("Manage plugins").click();
        cy.get("a#upload_plugin").contains("Upload plugin").click();

        cy.get("#uploadfile").click();
        cy.get("#uploadfile").selectFile(
            "t/cypress/fixtures/koha-plugin-ill-metadata-enrichment.kpz"
        );
        cy.get("input").contains("Upload").click();

        cy.intercept("GET", "/api/v1/ill/batchstatuses", {
            statusCode: 200,
            body: batchstatuses,
        }).as("get-batchstatuses");
    });
    afterEach(function () {
        //Restore ILLModule sys pref original value
        cy.set_syspref("ILLModule", this.syspref_ILLModule);
        //Clean-up created test batches
        cy.task("query", {
            sql: "DELETE from illbatches where name IN ('test batch', 'second test batch')",
        });
        //Uninstall plugin
        cy.visit("/cgi-bin/koha/plugins/plugins-home.pl");
        cy.get('.actions .btn-group.dropup a[id*="Pubmed"]')
            .contains("Actions")
            .click({ force: true })
            .closest(".btn-group.dropup")
            .find(".dropdown-item.uninstall_plugin")
            .click({ force: true });
    });
    it("ILL requests batch modal", function () {
        cy.visit("/cgi-bin/koha/mainpage.pl");
        cy.get("a.icon_ill").contains("ILL requests");
        cy.get("a.icon_ill").click();

        // Open batch modal
        cy.get("#ill-batch-backend-dropdown")
            .contains("New ILL requests batch")
            .click();
        cy.get(".dropdown-menu.show a").contains("Standard").click();
        cy.wait("@get-batchstatuses");
        cy.get("#ill-batch-modal").should("be.visible");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("be.disabled");

        // Create batch
        cy.get("#ill-batch-modal #name").type("test batch");
        cy.get("#ill-batch-modal #batchcardnumber").type("42");
        cy.get("#ill-batch-modal #branchcode").select("Centerville");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("not.be.disabled");
        cy.get("#ill-batch-modal #button_create_batch").click();
        cy.get("#ill-batch-modal #add_batch_items").should("be.visible");

        // Close modal
        cy.get("#ill-batch-modal #button_cancel_batch").click();
        cy.get("#ill-batch-modal").should("not.be.visible");

        // Reopen modal, button_create_batch must exist and be disabled
        cy.get("#ill-batch-backend-dropdown")
            .contains("New ILL requests batch")
            .click();
        cy.get(".dropdown-menu.show a").contains("Standard").click();
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("be.disabled");

        // Create a new batch
        cy.get("#ill-batch-modal #name").type("second test batch");
        cy.get("#ill-batch-modal #batchcardnumber").type("42");
        cy.get("#ill-batch-modal #branchcode").select("Centerville");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("not.be.disabled");
        cy.get("#ill-batch-modal #button_create_batch").click();
        cy.get("#ill-batch-modal #add_batch_items").should("be.visible");

        // Add identifiers + Mock plugin (pubmedid) API responses
        let pubmedid = "123";
        cy.intercept(
            "GET",
            "/api/v1/contrib/pubmed/esummary?pmid=" + pubmedid,
            {
                statusCode: 200,
                body: pubmedid_metadata_response,
            }
        ).as("get-pubmedid-metadata");
        cy.intercept("POST", "/api/v1/contrib/pubmed/parse_to_ill", {
            statusCode: 200,
            body: parse_to_ill_response,
        }).as("get-parse_to_ill");
        cy.get("#ill-batch-modal #identifiers_input").type(pubmedid);
        cy.get("#ill-batch-modal #process-button")
            .contains("Process identifiers")
            .click();
        cy.wait("@get-pubmedid-metadata");
        cy.wait("@get-parse_to_ill");
        cy.get("#ill-batch-modal #create-requests-button").should("exist");

        // Close modal
        cy.get("#ill-batch-modal #button_cancel_batch").click();
        cy.get("#ill-batch-modal").should("not.be.visible");

        // Reopen modal, #identifier-table_wrapper must not be visible
        cy.get("#ill-batch-backend-dropdown")
            .contains("New ILL requests batch")
            .click();
        cy.get(".dropdown-menu.show a").contains("Standard").click();
        cy.get("#identifier-table_wrapper").should("not.be.visible");
    });
});

describe("AutoILLBackendPriority syspref", () => {
    let original_plugin_restricted;
    let kohaconf = "/etc/koha/sites/kohadev/koha-conf.xml";
    beforeEach(() => {
        cy.login();
        cy.task("query", {
            sql: "SELECT value FROM systempreferences WHERE variable='ILLModule'",
        }).then(rows => {
            cy.wrap(rows[0].value).as("syspref_ILLModule");
        });
        cy.set_syspref("ILLModule", 1);
        cy.task("query", {
            sql: "SELECT value FROM systempreferences WHERE variable='AutoILLBackendPriority'",
        }).then(rows => {
            cy.wrap(rows[0].value).as("syspref_AutoILLBackendPriority");
        });
        cy.set_syspref("AutoILLBackendPriority", "PluginBackend");
        cy.task("readXmlElementValue", {
            filePath: kohaconf,
            element: "plugins_restricted",
        }).then(value => {
            original_plugin_restricted = value;
            if (value == "1") {
                cy.task("modifyXmlElement", {
                    filePath: kohaconf,
                    element: "plugins_restricted",
                    value: "0",
                });
            }
        });
        cy.title().should("eq", "Koha staff interface");
        cy.get("a.icon_administration").contains("Koha administration").click();
        cy.get("a").contains("Manage plugins").click();
        cy.get("a#upload_plugin").contains("Upload plugin").click();

        cy.get("#uploadfile").click();
        cy.get("#uploadfile").selectFile(
            "t/cypress/fixtures/koha-plugin-ill-metadata-enrichment.kpz"
        );
        cy.get("input").contains("Upload").click();

        // Install dummy backend plugin compatibly with AutoILLBackendPriority and ILL batches
        cy.visit("/cgi-bin/koha/plugins/plugins-home.pl");
        cy.get("a#upload_plugin").contains("Upload plugin").click();
        cy.get("#uploadfile").click();
        cy.get("#uploadfile").selectFile(
            "t/cypress/fixtures/koha-plugin-ill-backend.kpz"
        );
        cy.get("input").contains("Upload").click();

        cy.intercept("GET", "/api/v1/ill/batchstatuses", {
            statusCode: 200,
            body: batchstatuses,
        }).as("get-batchstatuses");
    });
    afterEach(function () {
        //Restore ILLModule sys pref original value
        cy.set_syspref("ILLModule", this.syspref_ILLModule);
        // Restore AutoILLBackendPriority original value
        cy.set_syspref(
            "AutoILLBackendPriority",
            this.syspref_AutoILLBackendPriority
        );
        //Restore plugins_restricted original value
        cy.task("modifyXmlElement", {
            filePath: kohaconf,
            element: "plugins_restricted",
            value: original_plugin_restricted,
        });
        //Clean-up created test batches
        cy.task("query", {
            sql: "DELETE from illbatches",
        });
        //Clean-up installed plugin(s)
        cy.task("query", {
            sql: "DELETE from plugin_data",
        });
        cy.task("query", {
            sql: "DELETE from plugin_methods",
        });
    });

    it("AutoILLBackendPriority: Backend error", function () {
        // ILL toolbar
        cy.visit("/cgi-bin/koha/ill/ill-requests.pl");
        cy.get("#ill-batch-backend-dropdown").should("not.exist");
        cy.get(".ill-toolbar a.btn-default")
            .contains("New ILL requests batch")
            .click();
        cy.wait("@get-batchstatuses");

        // Modal
        cy.get("#ill-batch-modal").should("be.visible");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("be.disabled");

        // Create a batch
        cy.get("#ill-batch-modal #name").type("second test batch");
        cy.get("#ill-batch-modal #batchcardnumber").type("42");
        cy.get("#ill-batch-modal #branchcode").select("Centerville");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("not.be.disabled");
        cy.get("#ill-batch-modal #button_create_batch").click();
        cy.get("#ill-batch-modal #add_batch_items").should("be.visible");

        // Add identifiers + Mock plugin (pubmedid) API responses
        let pubmedid = "123";
        cy.intercept(
            "GET",
            "/api/v1/contrib/pubmed/esummary?pmid=" + pubmedid,
            {
                statusCode: 200,
                body: pubmedid_metadata_response,
            }
        ).as("get-pubmedid-metadata");
        cy.intercept("POST", "/api/v1/contrib/pubmed/parse_to_ill", {
            statusCode: 200,
            body: parse_to_ill_response,
        }).as("get-parse_to_ill");
        cy.intercept(
            "GET",
            "/api/v1/contrib/pluginbackend/ill_backend_availability_pluginbackend*",
            {
                statusCode: 404,
                body: {
                    error: "Provided ISBN is not available in PluginBackend",
                },
            }
        ).as("get-backend_availability_response");

        cy.get("#ill-batch-modal #identifiers_input").type(pubmedid);
        cy.get("#ill-batch-modal #process-button")
            .contains("Process identifiers")
            .click();
        cy.wait("@get-pubmedid-metadata");
        cy.wait("@get-parse_to_ill");
        cy.wait("@get-backend_availability_response");
        cy.get("#identifier-table .dt-column-title")
            .contains("Auto backend")
            .should("exist");
        cy.get("#ill-batch-modal #create-requests-button").should("exist");

        //Plugin backend came back with error, Standard should be checked
        cy.get("input[name='auto_backend_0']").first().should("not.be.checked");
        cy.get("input[name='auto_backend_0']").eq(1).should("be.checked");
    });

    it("AutoILLBackendPriority: Backend warning", function () {
        // ILL toolbar
        cy.visit("/cgi-bin/koha/ill/ill-requests.pl");
        cy.get("#ill-batch-backend-dropdown").should("not.exist");
        cy.get(".ill-toolbar a.btn-default")
            .contains("New ILL requests batch")
            .click();
        cy.wait("@get-batchstatuses");

        // Modal
        cy.get("#ill-batch-modal").should("be.visible");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("be.disabled");

        // Create a batch
        cy.get("#ill-batch-modal #name").type("second test batch");
        cy.get("#ill-batch-modal #batchcardnumber").type("42");
        cy.get("#ill-batch-modal #branchcode").select("Centerville");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("not.be.disabled");
        cy.get("#ill-batch-modal #button_create_batch").click();
        cy.get("#ill-batch-modal #add_batch_items").should("be.visible");

        // Add identifiers + Mock plugin (pubmedid) API responses
        let pubmedid = "123";
        cy.intercept(
            "GET",
            "/api/v1/contrib/pubmed/esummary?pmid=" + pubmedid,
            {
                statusCode: 200,
                body: pubmedid_metadata_response,
            }
        ).as("get-pubmedid-metadata");
        cy.intercept("POST", "/api/v1/contrib/pubmed/parse_to_ill", {
            statusCode: 200,
            body: parse_to_ill_response,
        }).as("get-parse_to_ill");
        cy.intercept(
            "GET",
            "/api/v1/contrib/pluginbackend/ill_backend_availability_pluginbackend*",
            {
                statusCode: 200,
                body: {
                    warning:
                        "May be placed but will have to go through human verification",
                },
            }
        ).as("get-backend_availability_response");

        cy.get("#ill-batch-modal #identifiers_input").type(pubmedid);
        cy.get("#ill-batch-modal #process-button")
            .contains("Process identifiers")
            .click();
        cy.wait("@get-pubmedid-metadata");
        cy.wait("@get-parse_to_ill");
        cy.wait("@get-backend_availability_response");
        cy.get("#identifier-table .dt-column-title")
            .contains("Auto backend")
            .should("exist");
        cy.get("#ill-batch-modal #create-requests-button").should("exist");

        //Plugin backend came back with warning, Standard should be checked
        cy.get("input[name='auto_backend_0']").first().should("not.be.checked");
        cy.get("input[name='auto_backend_0']").eq(1).should("be.checked");
    });

    it("AutoILLBackendPriority: Backend success", function () {
        // ILL toolbar
        cy.visit("/cgi-bin/koha/ill/ill-requests.pl");
        cy.get("#ill-batch-backend-dropdown").should("not.exist");
        cy.get(".ill-toolbar a.btn-default")
            .contains("New ILL requests batch")
            .click();
        cy.wait("@get-batchstatuses");

        // Modal
        cy.get("#ill-batch-modal").should("be.visible");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("be.disabled");

        // Create a batch
        cy.get("#ill-batch-modal #name").type("second test batch");
        cy.get("#ill-batch-modal #batchcardnumber").type("42");
        cy.get("#ill-batch-modal #branchcode").select("Centerville");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("not.be.disabled");
        cy.get("#ill-batch-modal #button_create_batch").click();
        cy.get("#ill-batch-modal #add_batch_items").should("be.visible");

        // Add identifiers + Mock plugin (pubmedid) API responses
        let pubmedid = "123";
        cy.intercept(
            "GET",
            "/api/v1/contrib/pubmed/esummary?pmid=" + pubmedid,
            {
                statusCode: 200,
                body: pubmedid_metadata_response,
            }
        ).as("get-pubmedid-metadata");
        cy.intercept("POST", "/api/v1/contrib/pubmed/parse_to_ill", {
            statusCode: 200,
            body: parse_to_ill_response,
        }).as("get-parse_to_ill");
        cy.intercept(
            "GET",
            "/api/v1/contrib/pluginbackend/ill_backend_availability_pluginbackend*",
            {
                statusCode: 200,
                body: { success: "" },
            }
        ).as("get-backend_availability_response");

        cy.get("#ill-batch-modal #identifiers_input").type(pubmedid);
        cy.get("#ill-batch-modal #process-button")
            .contains("Process identifiers")
            .click();
        cy.wait("@get-pubmedid-metadata");
        cy.wait("@get-parse_to_ill");
        cy.wait("@get-backend_availability_response");
        cy.get("#identifier-table .dt-column-title")
            .contains("Auto backend")
            .should("exist");
        cy.get("#ill-batch-modal #create-requests-button").should("exist");

        //Plugin backend came back with success, PluginBackend should be checked
        cy.get("input[name='auto_backend_0']").first().should("be.checked");
        cy.get("input[name='auto_backend_0']").eq(1).should("not.be.checked");
    });

    it("AutoILLBackendPriority: Select-all bar applies backend to all rows", function () {
        // ILL toolbar
        cy.visit("/cgi-bin/koha/ill/ill-requests.pl");
        cy.get("#ill-batch-backend-dropdown").should("not.exist");
        cy.get(".ill-toolbar a.btn-default")
            .contains("New ILL requests batch")
            .click();
        cy.wait("@get-batchstatuses");

        // Modal
        cy.get("#ill-batch-modal").should("be.visible");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("be.disabled");

        // Create a batch
        cy.get("#ill-batch-modal #name").type("second test batch");
        cy.get("#ill-batch-modal #batchcardnumber").type("42");
        cy.get("#ill-batch-modal #branchcode").select("Centerville");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("not.be.disabled");
        cy.get("#ill-batch-modal #button_create_batch").click();
        cy.get("#ill-batch-modal #add_batch_items").should("be.visible");

        // Stage 2 identifiers, both get PluginBackend success
        cy.intercept("GET", "/api/v1/contrib/pubmed/esummary*", {
            statusCode: 200,
            body: pubmedid_metadata_response,
        }).as("get-pubmedid-metadata");
        cy.intercept("POST", "/api/v1/contrib/pubmed/parse_to_ill", {
            statusCode: 200,
            body: parse_to_ill_response,
        }).as("get-parse_to_ill");
        cy.intercept(
            "GET",
            "/api/v1/contrib/pluginbackend/ill_backend_availability_pluginbackend*",
            {
                statusCode: 200,
                body: { success: "" },
            }
        ).as("get-backend-availability");

        cy.get("#ill-batch-modal #identifiers_input").type("123{enter}456");
        cy.get("#ill-batch-modal #process-button")
            .contains("Process identifiers")
            .click();
        cy.wait("@get-pubmedid-metadata");
        cy.wait("@get-parse_to_ill");
        cy.wait("@get-backend-availability");
        // Wait for all rows to finish processing
        cy.get("#create-requests").should("not.have.css", "display", "none");

        // Both rows: PluginBackend selected (index 0), Standard not selected (index 1)
        cy.get("input[name='auto_backend_0']").first().should("be.checked");
        cy.get("input[name='auto_backend_1']").first().should("be.checked");

        // Select-all bar is visible with one option per backend
        cy.get("#batch-auto-backend-select-all").should("be.visible");
        cy.get(
            "#batch-auto-backend-select-all input[value='PluginBackend']"
        ).should("exist");
        cy.get("#batch-auto-backend-select-all input[value='Standard']").should(
            "exist"
        );

        // Click Standard in select-all → both rows switch to Standard
        cy.get(
            "#batch-auto-backend-select-all input[value='Standard']"
        ).click();
        cy.get("input[name='auto_backend_0']").eq(1).should("be.checked");
        cy.get("input[name='auto_backend_1']").eq(1).should("be.checked");
    });

    it("AutoILLBackendPriority: Select-all skips rows where selected backend is disabled", function () {
        // ILL toolbar
        cy.visit("/cgi-bin/koha/ill/ill-requests.pl");
        cy.get("#ill-batch-backend-dropdown").should("not.exist");
        cy.get(".ill-toolbar a.btn-default")
            .contains("New ILL requests batch")
            .click();
        cy.wait("@get-batchstatuses");

        // Modal
        cy.get("#ill-batch-modal").should("be.visible");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("be.disabled");

        // Create a batch
        cy.get("#ill-batch-modal #name").type("second test batch");
        cy.get("#ill-batch-modal #batchcardnumber").type("42");
        cy.get("#ill-batch-modal #branchcode").select("Centerville");
        cy.get("#ill-batch-modal #button_create_batch")
            .should("exist")
            .and("not.be.disabled");
        cy.get("#ill-batch-modal #button_create_batch").click();
        cy.get("#ill-batch-modal #add_batch_items").should("be.visible");

        // Single identifier with PluginBackend error → Standard selected.
        // Clicking PluginBackend in the select-all bar must leave it unchanged
        // because PluginBackend is disabled for this row.
        cy.intercept("GET", "/api/v1/contrib/pubmed/esummary?pmid=123", {
            statusCode: 200,
            body: pubmedid_metadata_response,
        }).as("get-pubmedid-metadata");
        cy.intercept("POST", "/api/v1/contrib/pubmed/parse_to_ill", {
            statusCode: 200,
            body: parse_to_ill_response,
        }).as("get-parse_to_ill");
        cy.intercept(
            "GET",
            "/api/v1/contrib/pluginbackend/ill_backend_availability_pluginbackend*",
            {
                statusCode: 404,
                body: { error: "Not available" },
            }
        ).as("get-backend-availability");

        cy.get("#ill-batch-modal #identifiers_input").type("123");
        cy.get("#ill-batch-modal #process-button")
            .contains("Process identifiers")
            .click();
        cy.wait("@get-pubmedid-metadata");
        cy.wait("@get-parse_to_ill");
        cy.wait("@get-backend-availability");

        // PluginBackend errored → Standard selected for row 0
        cy.get("input[name='auto_backend_0']").eq(1).should("be.checked");

        // Clicking PluginBackend in select-all must not change the row
        // because PluginBackend is disabled for it
        cy.get(
            "#batch-auto-backend-select-all input[value='PluginBackend']"
        ).click();
        cy.get("input[name='auto_backend_0']").eq(1).should("be.checked");
    });
});
