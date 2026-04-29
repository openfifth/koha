<template>
    <template v-if="modalType === 'select'">
        <span class="user">
            {{ resource.patron_str }}
        </span>
        &nbsp;
        <a @click="selectPatron()" class="btn btn-default"
            ><i class="fa fa-plus"></i> {{ $__("Select user") }}</a
        >
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
        const formatExistingPatrons = () => {
            if (!props.resource[props.fieldName]) return [];
            return props.resource[props.fieldName].map(ep => {
                return {
                    borrowernumber: ep.borrowernumber,
                    name: $patron_to_html(ep.patron),
                };
            });
        };
        const addedPatrons =
            props.modalType === "add" ? ref([...formatExistingPatrons()]) : [];

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

        const passSearchDataToModal = () => {
            if (props.filteredUrl) {
                $("#vuePatronSearchData").data(
                    "patron_search_filter",
                    props.filteredUrl
                );
            }
            $("#vuePatronSearchData").data("action_type", props.modalType);
            $("#vuePatronSearchData").data(
                "additional_patron_filters",
                filters.value
            );
            $("#vuePatronSearchData").data(
                "callback",
                props.modalType === "select"
                    ? newPatronSelected
                    : newPatronAdded
            );
        };
        onMounted(() => {
            passSearchDataToModal();
            $("#memberresultst").DataTable().clear().destroy();
            buildDatatable();
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
            passSearchDataToModal();
            $("#patron_search_modal").modal("show");
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
