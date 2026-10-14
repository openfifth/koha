<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
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
            apiClient: APIClient.import_batch_profiles.import_batch_profiles,
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
                },
                selectAttr("record_type", $__("Record type"), recordTypes, {
                    defaultValue: "biblio",
                }),
                selectAttr("encoding", $__("Character encoding"), encodings, {
                    defaultValue: "UTF-8",
                }),
                selectAttr("format", $__("Format"), formats, {
                    defaultValue: "ISO2709",
                }),
                selectAttr(
                    "overlay_action",
                    $__("Action if matching record found"),
                    overlayActions,
                    { defaultValue: "replace" }
                ),
                selectAttr(
                    "nomatch_action",
                    $__("Action if no match is found"),
                    nomatchActions,
                    { defaultValue: "create_new" }
                ),
                {
                    name: "parse_items",
                    type: "checkbox",
                    label: $__("Check for embedded item record data"),
                    defaultValue: true,
                },
                selectAttr(
                    "item_action",
                    $__("How to process items"),
                    itemActions,
                    { defaultValue: "always_add" }
                ),
                {
                    name: "comments",
                    type: "text",
                    label: $__("Comments"),
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
