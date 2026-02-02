import { markRaw } from "vue";

import Home from "../components/Shibboleth/Home.vue";
import ResourceWrapper from "../components/ResourceWrapper.vue";
import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/shibboleth/shibboleth.pl",
        is_default: true,
        is_base: true,
        title: $__("Shibboleth"),
        children: [
            {
                path: "",
                name: "ShibbolethHome",
                component: markRaw(Home),
                is_navigation_item: false,
            },
            {
                path: "/cgi-bin/koha/shibboleth/config",
                title: $__("Configuration"),
                icon: "fa fa-cog",
                is_end_node: true,
                resource: "Shibboleth/ShibbolethConfigResource.vue",
                children: [
                    {
                        path: "",
                        name: "ShibbolethConfigFormEdit",
                        component: markRaw(ResourceWrapper),
                        title: $__("Edit configuration"),
                    },
                ],
            },
            {
                path: "/cgi-bin/koha/shibboleth/mappings",
                title: $__("Field Mappings"),
                icon: "fa fa-exchange-alt",
                is_end_node: true,
                resource: "Shibboleth/ShibbolethMappingResource.vue",
                children: [
                    {
                        path: "",
                        name: "ShibbolethMappingsList",
                        component: markRaw(ResourceWrapper),
                    },
                    {
                        path: ":mapping_id",
                        name: "ShibbolethMappingsShow",
                        component: markRaw(ResourceWrapper),
                        title: $__("Show field mapping"),
                    },
                    {
                        path: "add",
                        name: "ShibbolethMappingsFormAdd",
                        component: markRaw(ResourceWrapper),
                        title: $__("Add field mapping"),
                    },
                    {
                        path: "edit/:mapping_id",
                        name: "ShibbolethMappingsFormEdit",
                        component: markRaw(ResourceWrapper),
                        title: $__("Edit field mapping"),
                    },
                ],
            },
        ],
    },
];
