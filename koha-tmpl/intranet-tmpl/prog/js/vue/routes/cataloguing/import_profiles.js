import { markRaw } from "vue";

import ResourceWrapper from "../../components/ResourceWrapper.vue";

import { $__ } from "@koha-vue/i18n";

export default {
    title: $__("Cataloging"),
    path: "",
    href: "/cgi-bin/koha/cataloguing/cataloging-home.pl",
    is_base: true,
    is_default: true,
    children: [
        {
            title: $__("Import profiles"),
            path: "/cgi-bin/koha/cataloguing/import_profiles",
            is_end_node: true,
            resource: "Cataloguing/ImportProfiles/ImportProfilesResource.vue",
            children: [
                {
                    path: "",
                    name: "ImportProfilesList",
                    component: markRaw(ResourceWrapper),
                },
                {
                    component: markRaw(ResourceWrapper),
                    name: "ImportProfilesFormAdd",
                    path: "add",
                    title: $__("Add import profile"),
                },
                {
                    component: markRaw(ResourceWrapper),
                    name: "ImportProfilesFormAddEdit",
                    path: "edit/:profile_id",
                    title: $__("Edit import profile"),
                },
            ],
        },
    ],
};
