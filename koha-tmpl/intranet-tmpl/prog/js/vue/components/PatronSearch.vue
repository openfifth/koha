<template>
    <template v-if="modalType === 'select'">
        <span class="user">
            {{ resource.patron_str }}
        </span>
        &nbsp;
        <a
            href="#patron_search_modal"
            @click="selectPatron()"
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
        <a @click="addPatron()" class="btn btn-default"
            ><i class="fa fa-plus"></i> {{ $__("Add user") }}</a
        >
        <input
            type="hidden"
            :name="`${name}_patron_ids`"
            :id="`${name}_patron_ids`"
        />
        <ol :id="`${name}_patron_names`">
            <li
                v-for="(patron, index) in addedPatrons"
                v-bind:key="index"
                :id="`${name}_patron_${patron.borrowernumber}`"
            >
                {{ patron.name }}
                <i
                    class="fa fa-trash"
                    style="cursor: pointer"
                    @click="deletePatron(patron.borrowernumber)"
                ></i>
            </li>
        </ol>
    </template>
</template>

<script>
import { computed, onBeforeMount, onMounted, ref } from "vue";

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
        const addedPatrons = ref([]);

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

        const passSearchDataToModal = () => {
            if (props.filteredUrl) {
                $("#vuePatronSearchData").data(
                    "patron_search_filter",
                    props.filteredUrl
                );
            }
            $("#vuePatronSearchData").data("action_type", props.modalType);
            $("#vuePatronSearchData").data(
                "callback",
                props.modalType === "select"
                    ? newPatronSelected
                    : newPatronAdded
            );
        };
        onMounted(() => {
            passSearchDataToModal();
        });

        const addPatron = () => {
            passSearchDataToModal();
            $("#patron_search_modal").modal("show");
            const modalEventListener = () => {
                newPatronsAdded();
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
        const newPatronAdded = (borrowernumber, name) => {
            if (
                !addedPatrons.value.find(
                    patron => patron.borrowernumber === borrowernumber
                )
            ) {
                addedPatrons.value.push({ borrowernumber, name });
                return 0;
            }
            return -1;
        };

        const newPatronsAdded = () => {
            props.resource[props.name] = addedPatrons.value.map(
                patron => patron.borrowernumber
            );
        };

        const selectPatron = () => {
            const modalEventListener = () => {
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
        const newPatronSelected = patron => {
            props.resource.patron = patron;
            props.resource.patron_str = $patron_to_html(patron);
            props.resource[props.name] = patron.patron_id;
            if (props.selectCallback) {
                props.selectCallback(patron);
            }
        };

        const deletePatron = borrowernumber => {
            const patronIndex = addedPatrons.value.findIndex(
                patron => patron.borrowernumber === borrowernumber
            );
            addedPatrons.value.splice(patronIndex, 1);
        };

        return {
            loading,
            shouldRenderInput,
            selectPatron,
            addPatron,
            newPatronSelected,
            filters,
            deletePatron,
            addedPatrons,
        };
    },
};
</script>

<style></style>
