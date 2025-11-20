<template>
    <div v-if="createItems.value === 'ordering'">
        <h3 style="margin-top: 1em">{{ $__("Bibliographic information") }}</h3>
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
    },
    inheritAttrs: false,
    setup(props) {
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
                required: resource => props.createItems.value === "ordering",
            },
            { name: "author", type: "text", label: $__("Author") },
            { name: "publisher", type: "text", label: $__("Publisher") },
            { name: "edition_statement", type: "text", label: $__("Edition") },
            {
                name: "publication_year",
                type: "text",
                label: $__("Publication year"),
            },
            { name: "isbn", type: "text", label: $__("ISBN") },
            ...(props.unimarc
                ? [{ name: "ean", type: "text", label: $__("EAN") }]
                : []),
            { name: "series_title", type: "text", label: $__("Series") },
            ...(!props.biblionumber
                ? [
                      {
                          name: "itemtype",
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
            props.resource.biblio = {};
            APIClient.item.item_types
                .getAll()
                .then(itemtypes => {
                    itemTypes.value = itemtypes;
                })
                .then(() => {
                    if (route.query.biblionumber) {
                        APIClient.biblios.biblios
                            .get(route.query.biblionumber)
                            .then(biblio => {
                                props.resource.biblio = biblio;
                            });
                    }
                });
        });

        return {
            biblioFields,
        };
    },
};
</script>

<style></style>
