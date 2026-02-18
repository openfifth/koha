<template>
    <div v-if="initialized && createItems.value === 'ordering'">
        <h3 v-if="!isSearch" style="margin-top: 1em">
            {{ $__("Bibliographic information") }}
        </h3>
        <ol>
            <li v-for="(attr, index) in biblioFields" v-bind:key="index">
                <FormElement
                    :resource="resource.biblio"
                    :attr="attr"
                    :index="index"
                />
            </li>
        </ol>
    </div>
</template>

<script>
import { computed, onBeforeMount, ref } from "vue";
import FormElement from "../../FormElement.vue";
import { APIClient } from "../../../fetch/api-client";
import { $__ } from "@koha-vue/i18n";
import { useRoute } from "vue-router";

export default {
    components: { FormElement },
    props: {
        resource: Object,
        useAcqFramework: { type: Boolean, default: false },
        unimarc: { type: Boolean, default: false },
        biblionumber: { type: String, default: null },
        createItems: Object,
        isSearch: { type: Boolean, default: false },
    },
    inheritAttrs: false,
    setup(props) {
        const initialized = ref(false);
        const itemTypes = ref([]);
        const route = useRoute();

        const getItemTypes = computed(() => {
            return itemTypes.value;
        });

        const biblioFields = [
            {
                name: "title",
                type: "text",
                label: $__("Title"),
                required: props.isSearch
                    ? false
                    : resource => props.createItems.value === "ordering",
            },
            { name: "author", type: "text", label: $__("Author") },
            ...(!props.isSearch
                ? [{ name: "publisher", type: "text", label: $__("Publisher") }]
                : []),
            ...(!props.isSearch
                ? [
                      {
                          name: "edition_statement",
                          type: "text",
                          label: $__("Edition"),
                      },
                  ]
                : []),
            ...(!props.isSearch
                ? [
                      {
                          name: "publication_year",
                          type: "text",
                          label: $__("Publication year"),
                      },
                  ]
                : []),
            { name: "isbn", type: "text", label: $__("ISBN") },
            ...(props.unimarc
                ? [{ name: "ean", type: "text", label: $__("EAN") }]
                : []),
            ...(!props.isSearch
                ? [{ name: "series_title", type: "text", label: $__("Series") }]
                : []),
            ...(!props.biblionumber && !props.isSearch
                ? [
                      {
                          name: "item_type",
                          type: "select",
                          label: $__("Item type"),
                          selectLabel: "description",
                          requiredKey: "item_type_id",
                          options: getItemTypes,
                      },
                  ]
                : []),
        ];

        onBeforeMount(() => {
            APIClient.item.item_types
                .getAll()
                .then(itemtypes => {
                    itemTypes.value = itemtypes;
                })
                .then(() => {
                    if (!props.resource.biblio) props.resource.biblio = {};
                    if (route.query.biblionumber) {
                        props.resource.biblio = {};
                        APIClient.biblios.biblios
                            .get(route.query.biblionumber)
                            .then(biblio => {
                                props.resource.biblio = biblio;
                                initialized.value = true;
                            });
                    } else {
                        initialized.value = true;
                    }
                });
        });

        return {
            biblioFields,
            initialized,
        };
    },
};
</script>

<style></style>
