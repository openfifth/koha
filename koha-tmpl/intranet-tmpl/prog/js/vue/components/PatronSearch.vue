<template>
    <span v-if="loading" class="user">
        {{ $__("Loading...") }}
    </span>
    <span v-else class="user">
        {{ resource.patron_str }}
    </span>
    &nbsp;
    <template v-if="modalType === 'select'">
        <a
            href="#patron_search_modal"
            @click="selectUser()"
            class="btn btn-default"
            data-bs-toggle="modal"
            data-bs-target="#patron_search_modal"
            ><i class="fa fa-plus"></i> {{ $__("Select user") }}</a
        >
        <input
            type="hidden"
            id="additional_patron_filters"
            :data-additionalfilters="filters"
        />
        <input
            v-if="shouldRenderInput"
            type="hidden"
            name="selected_patron_id"
            id="selected_patron_id"
        />
    </template>
    <template v-if="modalType === 'add'">
        <a @click="addUser()" class="btn btn-default"
            ><i class="fa fa-plus"></i> {{ $__("Add user") }}</a
        >
        <input
            type="hidden"
            :name="`${name}_users_ids`"
            :id="`${name}_users_ids`"
        />
        <ol :id="`${name}_users_names`"></ol>
    </template>
</template>

<script>
import { computed, onBeforeMount, onMounted, ref, watch } from "vue";
import { APIClient } from "../fetch/api-client.js";

export default {
    inheritAttrs: false,
    props: {
        name: String,
        resource: Object,
        label: String,
        required: Boolean,
        additionalFilters: Object,
        selectCallback: Function,
        fieldName: {
            type: String,
            default: "patron",
        },
        filteredUrl: String,
        modalType: {
            type: String,
            default: "select",
        },
    },
    setup(props) {
        const loading = ref(false);

        onBeforeMount(() => {
            if (props.modalType === "select") {
                props.resource.patron_str = $patron_to_html(
                    props.resource[props.fieldName]
                );
            }
        });

        const filters = computed(() => {
            if (!props.additionalFilters) return "";
            const checkForRefs = Object.keys(props.additionalFilters).reduce(
                (acc, filter) => {
                    if (typeof props.additionalFilters[filter] === "object") {
                        acc[filter] = props.additionalFilters[filter].value;
                        return acc;
                    }
                    acc[filter] = props.additionalFilters[filter];
                    return acc;
                },
                {}
            );
            return JSON.stringify(checkForRefs);
        });

        const shouldRenderInput = computed(() => {
            return !document.getElementById("selected_patron_id");
        });

        const addPatronData = () => {
            if (props.filteredUrl) {
                $("#vuePatronSearchData").data(
                    "patron_search_filter",
                    props.filteredUrl
                );
            }
            $("#vuePatronSearchData").data("action_type", props.modalType);
            $("#vuePatronSearchData").data("field_name", props.name);
        };
        onMounted(() => {
            addPatronData();
        });

        const addUser = () => {
            addPatronData();
            $("#patron_search_modal").modal("show");
            const modalEventListener = () => {
                newUserAdded();
                $(document).off(
                    "hidden.bs.modal",
                    "#patron_search_modal",
                    modalEventListener
                );
            };
            $(document).on(
                "hidden.bs.modal",
                "#patron_search_modal",
                modalEventListener
            );
        };

        const newUserAdded = () => {
            const userIds = document.getElementById(
                `${props.name}_users_ids`
            ).value;
            props.resource[props.name] = userIds.split(":");
        };

        const selectUser = () => {
            const modalEventListener = () => {
                newUserSelected();
                $(document).off(
                    "hidden.bs.modal",
                    "#patron_search_modal",
                    modalEventListener
                );
            };
            $(document).on(
                "hidden.bs.modal",
                "#patron_search_modal",
                modalEventListener
            );
        };
        const newUserSelected = e => {
            loading.value = true;
            let selected_patron_id =
                document.getElementById("selected_patron_id").value;
            let patron;
            const client = APIClient.patron;
            client.patrons.get(selected_patron_id).then(p => {
                patron = p;
                props.resource.patron = patron;
                props.resource.patron_str = $patron_to_html(patron);
                props.resource[props.name] = patron.patron_id;
                if (props.selectCallback) {
                    props.selectCallback(patron);
                }
                loading.value = false;
            });
        };

        return {
            loading,
            shouldRenderInput,
            selectUser,
            addUser,
            newUserSelected,
            filters,
        };
    },
};
</script>

<style></style>
