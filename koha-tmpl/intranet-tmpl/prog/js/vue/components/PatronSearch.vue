<template>
    <span v-if="loading" class="user">
        {{ $__("Loading...") }}
    </span>
    <span v-else class="user">
        {{ resource.patron_str }}
    </span>
    &nbsp;
    <a
        href="#patron_search_modal"
        @click="selectUser()"
        class="btn btn-default"
        data-bs-toggle="modal"
        ><i class="fa fa-plus"></i> {{ $__("Select user") }}</a
    >
    <input
        type="hidden"
        name="selected_patron_id"
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

<script>
import { computed, onBeforeMount, ref } from "vue";
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
    },
    setup(props) {
        const loading = ref(false);

        onBeforeMount(() => {
            props.resource.patron_str = $patron_to_html(props.resource.patron);
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
                props.resource.user_id = patron.patron_id;
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
            newUserSelected,
            filters,
        };
    },
};
</script>

<style></style>
