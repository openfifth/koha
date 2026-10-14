<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { ref } from "vue";
import BaseResource from "../../BaseResource.vue";
import { useBaseResource } from "../../../composables/base-resource.js";
import { APIClient } from "../../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";
import {
    recordTypes,
    encodings,
    formats,
    overlayActions,
    nomatchActions,
    itemActions,
} from "./options.js";

// DataTables inserts render() output as HTML, so escape database values
// (escape_str is Koha's global helper from staff-global.js).
const escapedColumn = (name, title) => ({
    title,
    data: name,
    searchable: true,
    orderable: true,
    render: (data, type) => (type === "display" ? escape_str(data) : data),
});

const selectAttr = (name, label, options, extra = {}) => ({
    name,
    type: "select",
    label,
    options,
    requiredKey: "value",
    selectLabel: "label",
    ...extra,
});

export default {
    props: {
        routeAction: String,
    },
    setup(props) {
        // These are replaced, never mutated in place: vue-select only turns a
        // stored id back into its label when its `options` prop changes
        // identity, so options that arrive after the form has rendered (the
        // Duplicate and Edit routes) would otherwise leave the raw id showing.
        const matchers = ref([]);
        const templates = ref([]);
        // Per-lookup state: "Unknown" is only truthful if that lookup loaded.
        const matchersLoaded = ref(false);
        const templatesLoaded = ref(false);
        const lookupName = (id, loaded, find, nameOf) => {
            if (id === null || id === undefined) return "";
            if (!loaded.value) return $__("Unavailable (%s)").format(id);
            const found = find(id);
            return found ? nameOf(found) : $__("Unknown (%s)").format(id);
        };
        const matcherName = id =>
            lookupName(
                id,
                matchersLoaded,
                id => matchers.value.find(x => x.record_matcher_id === id),
                m => m.label
            );
        const templateName = id =>
            lookupName(
                id,
                templatesLoaded,
                id =>
                    templates.value.find(
                        x => x.marc_modification_template_id === id
                    ),
                t => t.name
            );
        // The list renders its rows once, so it must not be shown until the
        // names are known. This relies on ResourceList's getResourceCount()
        // awaiting apiClient.count() before it sets `initialized`, which is
        // what mounts the table: the count request is held back until then.
        // A failed lookup is already reported by HttpClient (setError); we
        // only record that it failed so the list does not claim "Unknown".
        const lookupsLoaded = Promise.all([
            APIClient.record_matchers.record_matchers
                .getAll()
                .then(rows => {
                    matchers.value = rows.map(r => ({
                        ...r,
                        label: `${r.code} (${r.description})`,
                    }));
                    matchersLoaded.value = true;
                })
                .catch(() => {}),
            APIClient.marc_modification_templates.marc_modification_templates
                .getAll()
                .then(rows => {
                    templates.value = rows;
                    templatesLoaded.value = true;
                })
                .catch(() => {}),
        ]);
        const profilesClient =
            APIClient.import_batch_profiles.import_batch_profiles;
        const apiClient = {
            ...profilesClient,
            count: (...args) =>
                lookupsLoaded.then(() => profilesClient.count(...args)),
        };

        const baseResource = useBaseResource({
            resourceName: "import_batch_profile",
            nameAttr: "name",
            idAttr: "profile_id",
            components: {
                show: null,
                list: "ImportProfilesList",
                add: "ImportProfilesFormAdd",
                edit: "ImportProfilesFormAddEdit",
            },
            apiClient,
            table: {
                resourceTableUrl:
                    APIClient.import_batch_profiles.httpClient._baseURL,
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to delete this import profile? Staged batches that used it are not affected."
                ),
                deleteSuccessMessage: $__("Import profile %s deleted"),
                displayName: $__("Import profile"),
                editLabel: $__("Edit import profile #%s"),
                emptyListMessage: $__("There are no import profiles defined"),
                newLabel: $__("New import profile"),
            },
            props,
            navigationOnFormSave: "ImportProfilesList",
            // The form is grouped like the "Stage MARC records for import"
            // page, but with shorter headings of our own. Groups appear in the
            // order of their first attribute below, and the list columns
            // follow that same order.
            groupLabels: {
                profile: $__("Profile"),
                file: $__("File format"),
                modification: $__("MARC modification"),
                matching: $__("Record matching"),
                items: $__("Items"),
            },
            resourceAttrs: [
                {
                    name: "profile_id",
                    required: true,
                    type: "text",
                    label: $__("ID"),
                    hideIn: ["Form"],
                },
                {
                    name: "name",
                    required: true,
                    type: "text",
                    label: $__("Name"),
                    group: "profile",
                    tableColumnDefinition: escapedColumn("name", $__("Name")),
                },
                selectAttr("record_type", $__("Record type"), recordTypes, {
                    group: "file",
                    defaultValue: "biblio",
                    tableColumnDefinition: escapedColumn(
                        "record_type",
                        $__("Record type")
                    ),
                }),
                selectAttr("encoding", $__("Character encoding"), encodings, {
                    group: "file",
                    defaultValue: "UTF-8",
                    tableColumnDefinition: escapedColumn(
                        "encoding",
                        $__("Character encoding")
                    ),
                }),
                selectAttr("format", $__("Format"), formats, {
                    group: "file",
                    defaultValue: "ISO2709",
                    tableColumnDefinition: escapedColumn(
                        "format",
                        $__("Format")
                    ),
                }),
                {
                    name: "template_id",
                    type: "select",
                    label: $__("MARC modification template"),
                    group: "modification",
                    get options() {
                        return templates.value;
                    },
                    requiredKey: "marc_modification_template_id",
                    selectLabel: "name",
                    defaultValue: null,
                    tableColumnDefinition: {
                        title: $__("MARC modification template"),
                        data: "template_id",
                        orderable: false,
                        searchable: false,
                        render: data => escape_str(templateName(data)),
                    },
                },
                {
                    name: "matcher_id",
                    type: "select",
                    label: $__("Record matching rule"),
                    group: "matching",
                    get options() {
                        return matchers.value;
                    },
                    requiredKey: "record_matcher_id",
                    selectLabel: "label",
                    // The API wants an integer or null here; without this the
                    // shared form builder sends "" for an untouched select.
                    defaultValue: null,
                    tableColumnDefinition: {
                        title: $__("Matching rule"),
                        data: "matcher_id",
                        orderable: false,
                        searchable: false,
                        render: data => escape_str(matcherName(data)),
                    },
                },
                selectAttr(
                    "overlay_action",
                    $__("Action if matching record found"),
                    overlayActions,
                    {
                        group: "matching",
                        defaultValue: "replace",
                        tableColumnDefinition: escapedColumn(
                            "overlay_action",
                            $__("Action if matching record found")
                        ),
                    }
                ),
                selectAttr(
                    "nomatch_action",
                    $__("Action if no match is found"),
                    nomatchActions,
                    {
                        group: "matching",
                        defaultValue: "create_new",
                        tableColumnDefinition: escapedColumn(
                            "nomatch_action",
                            $__("Action if no match is found")
                        ),
                    }
                ),
                {
                    name: "parse_items",
                    type: "checkbox",
                    label: $__("Check for embedded item record data"),
                    group: "items",
                    defaultValue: true,
                },
                selectAttr(
                    "item_action",
                    $__("How to process items"),
                    itemActions,
                    {
                        group: "items",
                        defaultValue: "always_add",
                        tableColumnDefinition: escapedColumn(
                            "item_action",
                            $__("How to process items")
                        ),
                    }
                ),
                {
                    name: "comments",
                    type: "text",
                    label: $__("Comments"),
                    group: "profile",
                    tableColumnDefinition: escapedColumn(
                        "comments",
                        $__("Comments")
                    ),
                },
            ],
        });

        const tableOptions = {
            url: baseResource.getResourceTableUrl(),
            actions: {
                "-1": [
                    "edit",
                    { delete: { text: $__("Delete"), icon: "fa fa-trash" } },
                ],
            },
        };

        const onFormSave = (e, profileToSave) => {
            e.preventDefault();
            const profile = JSON.parse(JSON.stringify(profileToSave)); // copy
            const profileId = profile.profile_id;
            delete profile.profile_id;

            if (profileId) {
                return baseResource.apiClient.update(profile, profileId).then(
                    result => {
                        baseResource.setMessage($__("Import profile updated!"));
                        return result;
                    },
                    () => {}
                );
            }
            return baseResource.apiClient.create(profile).then(
                result => {
                    baseResource.setMessage($__("Import profile created!"));
                    return result;
                },
                () => {}
            );
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
        };
    },
    name: "ImportProfilesResource",
    emits: ["select-resource"],
    components: {
        BaseResource,
    },
};
</script>
